HELM_UNITTEST_VERSION?=3.9.3-0.2.11

.PHONY: test
test: ## Run the helm unittest
	docker run -i $(shell [ -t 0 ] && echo '-t') --rm -v .:/apps quintush/helm-unittest:$(HELM_UNITTEST_VERSION) -3 .
