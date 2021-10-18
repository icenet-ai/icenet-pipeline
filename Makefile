

.phony: clean_data clean_train clean_results

clean_data:
	-rm -r processed/ network_datasets/ loader.*.json dataset_config.*.json

clean_train:
	-rm -r ensemble/laptop

clean_results:
	-rm -r results
