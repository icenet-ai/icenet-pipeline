

.phony: clean_data clean_train

clean_data:
	-rm -r processed/ network_datasets/ results/ loader.*.json dataset_config.*.json

clean_train:
	-rm -r ensemble/draft
