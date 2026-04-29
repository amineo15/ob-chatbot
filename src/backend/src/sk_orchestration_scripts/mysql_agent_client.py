# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

"""
Example script showing how to integrate a MySQL-powered agent into the
HandoffOrchestration on Azure AI Foundry.

The MySQL agent uses MySQLPlugin (a Semantic Kernel plugin) to query the
database and answer questions from the triage agent.

Run with the VSCode configuration "Python: Run mysql_agent_client.py as module".

Required environment variables (in addition to the standard ones):
    MYSQL_AGENT_ID   - Azure AI Foundry agent ID for the MySQL agent
    MYSQL_HOST       - MySQL server hostname
    MYSQL_PORT       - MySQL server port (default: 3306)
    MYSQL_USER       - MySQL username
    MYSQL_PASSWORD   - MySQL password
    MYSQL_DATABASE   - Default MySQL database
    MYSQL_SSL        - Enable SSL connection (default: true)
"""

import os
import asyncio
from semantic_kernel.agents import AzureAIAgent, OrchestrationHandoffs, HandoffOrchestration
from semantic_kernel.agents.runtime import InProcessRuntime
from semantic_kernel.contents import AuthorRole, ChatMessageContent
from azure.identity.aio import DefaultAzureCredential
from agents.mysql_plugin import MySQLPlugin
from dotenv import load_dotenv

load_dotenv()

PROJECT_ENDPOINT = os.environ.get("AGENTS_PROJECT_ENDPOINT")
MODEL_NAME = os.environ.get("AOAI_DEPLOYMENT")

AGENT_IDS = {
    "TRIAGE_AGENT_ID": os.environ.get("TRIAGE_AGENT_ID"),
    "MYSQL_AGENT_ID": os.environ.get("MYSQL_AGENT_ID"),
}


def human_response_function() -> ChatMessageContent:
    user_input = input("User: ")
    return ChatMessageContent(role=AuthorRole.USER, content=user_input)


def agent_response_callback(message: ChatMessageContent) -> None:
    if message.content:
        print(f"{message.name}: {message.content}")


async def main():
    async with DefaultAzureCredential(exclude_interactive_browser_credential=False) as creds:
        async with AzureAIAgent.create_client(credential=creds, endpoint=PROJECT_ENDPOINT) as client:

            # Triage agent routes the user's request
            triage_def = await client.agents.get_agent(AGENT_IDS["TRIAGE_AGENT_ID"])
            triage_agent = AzureAIAgent(
                client=client,
                definition=triage_def,
                description="A triage agent that routes database inquiries to the MySQL agent.",
            )

            # MySQL agent has access to the database via MySQLPlugin
            mysql_def = await client.agents.get_agent(AGENT_IDS["MYSQL_AGENT_ID"])
            mysql_agent = AzureAIAgent(
                client=client,
                definition=mysql_def,
                description=(
                    "An agent that queries a MySQL database. "
                    "Use list_databases, list_tables, describe_table, execute_query, "
                    "and execute_write tools to answer database-related questions."
                ),
                plugins=[MySQLPlugin()],
            )

            print("Agents initialized successfully.")
            print(f"Triage Agent ID: {triage_agent.id}")
            print(f"MySQL Agent ID:  {mysql_agent.id}")

            handoffs = (
                OrchestrationHandoffs()
                .add(
                    source_agent=triage_agent.name,
                    target_agent=mysql_agent.name,
                    description="Transfer to this agent for any database or MySQL related questions.",
                )
                .add(
                    source_agent=mysql_agent.name,
                    target_agent=triage_agent.name,
                    description="Transfer back to triage when the database query is complete or the question is not database-related.",
                )
            )

            orchestration = HandoffOrchestration(
                members=[triage_agent, mysql_agent],
                handoffs=handoffs,
                agent_response_callback=agent_response_callback,
                human_response_function=human_response_function,
            )

            runtime = InProcessRuntime()
            runtime.start()

            result = await orchestration.invoke(
                task="Show me the list of tables in the database",
                runtime=runtime,
            )

            try:
                value = await result.get()
                print(value)
            except Exception as e:
                print(f"[ERROR]: {e}")

            await runtime.stop_when_idle()


if __name__ == "__main__":
    asyncio.run(main())
    print("MySQL agent orchestration completed.")
