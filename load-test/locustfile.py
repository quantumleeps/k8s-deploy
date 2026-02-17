from locust import HttpUser, between, task


class RAGUser(HttpUser):
    wait_time = between(0.5, 2)

    @task(5)
    def health_check(self) -> None:
        self.client.get("/health")

    @task(1)
    def query(self) -> None:
        self.client.post(
            "/query",
            json={
                "question": "What is the maximum contaminant level for bromate?",
                "strategy": "fixed",
                "model": "voyage-3-large",
            },
        )
