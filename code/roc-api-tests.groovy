pipeline {
...
    stages {
        stage("Cleanup"){
	    ...
        }
        stage("Install Kind"){
	    ...
        }
        stage("Clone Test Repo"){
	    ...
        }
        stage("Setup Virtual Environment"){
	    ...
        }
        stage("Generate API Test Framework and API Tests"){
	    ...
        }
        stage("Run API Tests"){
	    ...
        }
        stage("Check for PENDING transactions"){
	    ...
        }
    }
    post {
        always {
	    ...
        }
        failure {
	    ...
        }
    }
}