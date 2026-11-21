up:
	kubectl apply -f patroni-rbac.yaml
	kubectl apply -f patroni-config.yaml
	kubectl apply -f pg-services.yaml
	kubectl apply -f postgres-statefulset.yaml
	@echo "Waiting for pods to be ready..."
	kubectl get pods -n pg-ha

down:
	kubectl delete -f postgres-statefulset.yaml
	kubectl delete -f pg-services.yaml
	kubectl delete -f patroni-config.yaml
	kubectl delete -f patroni-rbac.yaml

status:
	kubectl exec -n pg-ha pg-0 -- patronictl -c /tmp/patroni.yml list || kubectl exec -n pg-ha pg-1 -- patronictl -c /tmp/patroni.yml list || kubectl exec -n pg-ha pg-2 -- patronictl -c /tmp/patroni.yml list

test-failover:
	kubectl delete pod -n pg-ha pg-0
	@echo "Pod deleted. Waiting 60 seconds for Patroni to promote a new leader..."
	sleep 60
	kubectl get pods -n pg-ha
