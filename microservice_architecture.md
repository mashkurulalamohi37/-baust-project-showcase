# High-Performance Microservice Architecture Plan

## Goal
Maximize scalability and performance for the Project Showcase app by moving resource-intensive and fragile client-side operations to dedicated, high-performance backend microservices.

## The Bottleneck: Client-Side Scraping
Currently, `YoutubeTranscriptExtractor` runs on the user's device.
- **Risk**: If YouTube changes their HTML/API, the app breaks for *everyone* until you release a new update (which takes days).
- **Performance**: Wastes user battery and data.
- **Scalability**: No caching. 1000 users watching the same video = 1000 requests to YouTube.

## Proposed Solution: The "Go-Fast" Microservice Stack

We will implement a **Serverless Containerized Microservice** architecture.

### 1. The Core: Go (Golang) Microservice
We will build a dedicated service using **Go** (Golang).
- **Why?** Go is designed for high-concurrency cloud services. It starts instantly and uses very little memory.
- **Framework**: `Fiber` (Express-inspired, but incredibly fast) or `Gin`.
- **Hosting**: **Google Cloud Run**. It scales to zero (costs \$0 when idle) and scales to infinity (handles viral traffic spikes automatically).

### 2. The Speed Layer: Redis Caching
We will introduce **Redis** (e.g., via Redis Cloud or a managed instance).
- **Why?** Caching.
- **Scenario**: User A views a project. The service fetches the transcript from YouTube (takes ~2s). It saves it to Redis.
- **Benefit**: User B, C, and D view the same project. The service serves the transcript from Redis in **5 milliseconds**.

### 3. The Search Engine: Meilisearch (Optional but Recommended)
Firestore is poor at full-text search.
- **Solution**: Sync firestore documents to a **Meilisearch** instance.
- **Result**: "Filter by 'machine learning' in 2024" returns in <50ms with typo tolerance and highlighting.

## Implementation Steps

### Phase 1: Transcript Microservice (Immediate Win)
1.  **Create a `backend/` directory** in your repo.
2.  **Write a Go Server**:
    -   Endpoint: `GET /transcript?url=...`
    -   Logic: Check Cache -> Fetch from YouTube -> Save to Cache -> Return.
3.  **Containerize**: 
    -   Create a `Dockerfile` for the Go app (Multistage build for tiny image size < 20MB).
4.  **Deploy**:
    -   Deploy to Google Cloud Run.
5.  **Connect App**:
    -   Update `YoutubeTranscriptExtractor.dart` to call your new API instead of doing the work itself.

### Phase 2: AI Processing (Next Step)
-   Offload the Gemini AI summarization to this same backend (or a Python sibling service) to keep your API keys secure and never exposed in the app code.

## Why This is "Max Scalable"
-   **Stateless**: The Go service stores no data locally. It can run on 1 server or 10,000 servers.
-   **Serverless**: You don't manage servers. Google manages the scaling.
-   **Polyglot**: You are not tied to Dart/Flutter on the backend. You use the best tool for the job (Go for speed, Python for AI).
