# 🏛️ System Architecture: Collaborative Clinical Assessment System (CCAS)

This document outlines the architecture of the Collaborative Clinical Assessment System (CCAS), a multi-agent AI framework designed to generate comprehensive clinical summaries from patient data.

## 1. Core Philosophy

The CCAS is designed as a **Virtual Case Conference**. It moves beyond a simple, linear pipeline to a collaborative, multi-step process that emphasizes:

-   **Modularity:** Each component is independent and can be upgraded or replaced without affecting the entire system.
-   **Shared Context:** All agents have access to a unified, evolving view of the patient's case.
-   **Iterative Refinement:** Agents consult one another to refine their opinions, mirroring real-world specialist collaboration.
-   **Traceability:** The entire process is orchestrated and logged, ensuring every step is auditable.

## 2. Architectural Overview

The system is composed of a central **Orchestrator Agent** that manages a workflow across three distinct phases, utilizing a set of specialized **Tools**.

```mermaid
graph TD
    A[User Request] --> B[Orchestrator Agent];

    subgraph Phase 1: Context Generation
        B --> C{Tool A: Data Retriever};
        C --> D(SharedPatientContext Object);
        B --> E{Tool B: Clinical Feature Engine};
        E --> D;
    end

    subgraph Phase 2: Virtual Case Conference
        B --> F{Tool C: Specialist Agent Library};
        F -- reads --> D;
        F -- writes --> G[Initial & Refined Opinions];
        G -- updates --> D;
    end

    subgraph Phase 3: Synthesis
        B --> H[Synthesizer Agent];
        H -- reads --> D;
        H -- uses --> I{Tool D: Knowledge Base (RAG)};
        H --> J[Final Summary];
    end

    J --> K[Final Output to User];
```

## 3. Components in Detail

### 3.1. 🧠 The Orchestrator Agent

-   **Description:** The "Chief Resident" or central brain of the system. It is a stateful agent that manages the entire workflow from request intake to final delivery.
-   **Responsibilities:**
    -   Receives and parses the initial user request.
    -   Calls the necessary tools in a logical sequence.
    -   Manages the state of the `SharedPatientContext` object.
    -   Orchestrates the "Roundtable" consultation between specialist agents.
    -   Delivers the final summary.
-   **Implementation:** A Python script or class that directs the flow of logic and makes API calls to other components.

### 3.2. 📦 The SharedPatientContext Object

-   **Description:** A dynamic, in-memory JSON object that serves as the single source of truth for a single case. It is created at the start and progressively enriched throughout the workflow.
-   **Structure:**
    ```json
    {
      "case_id": "uuid-1234",
      "patient_id": "SYNTH-PATIENT-001",
      "time_period": { "start": "...", "end": "..." },
      "raw_data": {
        "conditions": ["..."],
        "medications": ["..."],
        "lab_results": { "...": [...] }
      },
      "engineered_features": {
        "eGFR_slope": -5.2,
        "blood_pressure_trend": "stable"
      },
      "agent_opinions": {
        "Nephrology": {
          "initial_opinion": "...",
          "refined_opinion": "..."
        },
        "Cardiology": { "...": "..." }
      }
    }
    ```

### 3.3. 🛠️ Tools (Services & Modules)

These are the functions and services the Orchestrator calls upon.

#### 🔧 Tool A: Data Retriever & Context Builder

-   **Purpose:** To fetch and structure patient data.
-   **Production Implementation:** Queries the Google Cloud Healthcare API (FHIR).
-   **Project Implementation:** A **`SyntheticPatientGenerator`** module that creates a realistic but fake `SharedPatientContext.raw_data` object based on pre-defined patient archetypes.

#### 🔧 Tool B: Clinical Feature Engine

-   **Purpose:** To analyze raw time-series data and extract meaningful trends.
-   **Production Implementation:** A data science service running statistical analysis (e.g., linear regression on time-series data).
-   **Project Implementation:** A **`MockFeatureEngine`** function that uses simple rules (e.g., `if last_value < first_value, trend = 'declining'`) to populate the `SharedPatientContext.engineered_features` section.

#### 🔧 Tool C: Specialist Agent Library

-   **Purpose:** A collection of domain-expert agents, each responsible for a specific medical specialty.
-   **Implementation:** Each "Specialist Agent" is a function that:
    1.  Receives the full `SharedPatientContext` as input.
    2.  Is powered by a powerful foundation LLM (e.g., Google Gemini) guided by a detailed **System Prompt**.
    3.  May call other sub-tools (like a mock predictive model) to inform its reasoning.
    4.  Outputs a structured JSON object containing its "opinion," which is then added to the `SharedPatientContext`.

#### 🔧 Tool D: Guideline & Knowledge Base (RAG)

-   **Purpose:** To provide external, trusted medical knowledge to ground the agents' reasoning.
-   **Production Implementation:** A vector database containing indexed medical textbooks and clinical guidelines.
-   **Project Implementation:** Can be simplified to a **`MockKnowledgeBase`**—a Python dictionary where a key (e.g., "CKD Management") maps to a pre-written string of text summarizing the relevant guideline.

### 3.4. 🎓 The Synthesizer Agent

-   **Description:** The "Chief Medical Officer" of the system. This is the final and most sophisticated agent.
-   **Responsibilities:**
    -   Receives the fully populated `SharedPatientContext` dossier.
    -   Analyzes the initial and refined opinions from all specialists.
    -   Identifies synergies, conflicts, and priorities.
    -   Generates the final, coherent, human-readable summary.
-   **Implementation:** A dedicated LLM call with a sophisticated system prompt that instructs it to perform high-level synthesis and conflict resolution.

## 4. Data and Control Flow

1.  **Initiation:** `User Request` -> `Orchestrator` creates a `SharedPatientContext`.
2.  **Enrichment:** `Orchestrator` uses `Tool A` and `Tool B` to populate the context with raw data and engineered features.
3.  **Initial Analysis:** `Orchestrator` calls relevant `Specialist Agents` from `Tool C` in parallel. Each agent reads the context and writes back its `initial_opinion`.
4.  **Collaboration ("Roundtable"):** `Orchestrator` re-engages the `Specialist Agents`, allowing them to read each other's initial opinions and produce a `refined_opinion`.
5.  **Synthesis:** `Orchestrator` passes the final, complete `SharedPatientContext` to the `Synthesizer Agent`.
6.  **Fact-Checking:** `Synthesizer Agent` can use `Tool D` to cross-reference its summary against known guidelines.
7.  **Delivery:** `Synthesizer Agent` returns the final summary text to the `Orchestrator`, which delivers it to the user.

This architecture provides a robust, scalable, and responsible framework for developing advanced clinical AI assistants.