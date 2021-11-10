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
            steps {
                sh """
                    mkdir -p /tmp/robotlogs
                    cd ${WORKSPACE}/api-tests
                    source ast-venv/bin/activate; set -u;
                    robot ${WORKSPACE}/api-tests/ap_list.robot || true
                    robot ${WORKSPACE}/api-tests/application.robot || true
                    robot ${WORKSPACE}/api-tests/connectivity_service.robot || true
                    robot ${WORKSPACE}/api-tests/device_group.robot || true
                    robot ${WORKSPACE}/api-tests/enterprise.robot || true
                    robot ${WORKSPACE}/api-tests/ip_domain.robot || true
                    robot ${WORKSPACE}/api-tests/site.robot || true
                    robot ${WORKSPACE}/api-tests/template.robot || true
                    robot ${WORKSPACE}/api-tests/traffic_class.robot || true
                    robot ${WORKSPACE}/api-tests/upf.robot || true
                    robot ${WORKSPACE}/api-tests/vcs.robot || true
                """
            }
        }
    }
...
}