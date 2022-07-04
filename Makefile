BUILD_DIR ?= build
FIRMWARE_REPO_PATH = mch2022-firmware-esp32
FIRMWARE_BUILD_PATH = $(FIRMWARE_REPO_PATH)/build
FLASHARGS_FILE = flashargs

# fatfs will be generated here, goes to partition
FATFS_CONTENTS_PATH = fatfs-contents
FATFS_PARTITION = locfd
FATFS_GEN_FLAGS = --long_name_support --sector_size 4096

#appfs will be generated here, goes to partition
APPFS_PARTITION = appfs
APPFS_GEN_PY = $(FIRMWARE_REPO_PATH)/components/appfs/tools/appfs_generate.py
APPFS_ADD_PY = $(FIRMWARE_REPO_PATH)/components/appfs/tools/appfs_add_file.py
SPONSORAPP_MAKE_PATH = mch2022-sponsors-slideshow/app
SPONSORAPP_PATH = mch2022-sponsors-slideshow/
SPONSORAPP_BIN = mch2022-sponsors-slideshow/app/build/main.bin

# firmware-generated images that go to partitions
MAIN_FILENAME = $(FIRMWARE_BUILD_PATH)/main.bin
MAIN_PARTITION = ota_0
OTADATA_FILENAME = $(FIRMWARE_BUILD_PATH)/ota_data_initial.bin
OTADATA_PARTITION = otadata
PHYINITDATA_FILENAME = $(FIRMWARE_BUILD_PATH)/phy_init_data.bin
PHYINITDATA_PARTITION = phy_init

# firmware-generated images that go to fixed addresses
BOOTLOADER_FILENAME = $(FIRMWARE_BUILD_PATH)/bootloader/bootloader.bin
BOOTLOADER_ADDRESS = 0x1000
PARTITIONTABLE_FILENAME = $(FIRMWARE_BUILD_PATH)/partition_table/partition-table.bin
PARTITIONTABLE_ADDRESS = 0x8000

# other needed paths and scripts 
FIRMWARE_IDF_PATH = $(FIRMWARE_REPO_PATH)/esp-idf
PATITION_TABLE_PATH = $(FIRMWARE_REPO_PATH)/partitions.csv
FATGEN_PY = esp-idf/components/fatfs/wl_fatfsgen.py
PARTINFO_PY = esp-idf/components/partition_table/parttool.py

# utility macros
PARTITION_OFFSET = $$($(PARTINFO_PY) -f $(PATITION_TABLE_PATH) get_partition_info --partition-name $(1) --info offset)
PARTITION_SIZE = $$($(PARTINFO_PY) -f $(PATITION_TABLE_PATH) get_partition_info --partition-name $(1) --info size)
SOURCE_FW_IDF = source "$(FIRMWARE_IDF_PATH)/export.sh" > /dev/null
BUILDBIN = $(BUILD_DIR)/$(1).bin
DECIMAL = $$(printf "%d" $(1))

.PHONY: firmware sponsorapp appfs fatfs bootloader partitiontable main otadata phyinitdata flashargs clean

all: flashargs

firmware:
	cd $(FIRMWARE_REPO_PATH) && make prepare && make build

sponsorapp:
	$(SOURCE_FW_IDF) &&	cd $(SPONSORAPP_MAKE_PATH) && idf.py build

appfs: sponsorapp
	$(SOURCE_FW_IDF) &&	python $(APPFS_GEN_PY) $(call DECIMAL,$(call PARTITION_SIZE,$(APPFS_PARTITION))) $(call BUILDBIN,$(APPFS_PARTITION))
	$(SOURCE_FW_IDF) &&	python $(APPFS_ADD_PY) $(call BUILDBIN,$(APPFS_PARTITION)) $(SPONSORAPP_BIN) sponsorapp "Sponsor Slideshow" 1

fatfs:
	mkdir -p $(BUILD_DIR)
	$(SOURCE_FW_IDF) && $(FATGEN_PY) $(FATFS_GEN_FLAGS) --partition_size $(call PARTITION_SIZE,$(FATFS_PARTITION)) --output_file $(call BUILDBIN,$(FATFS_PARTITION)) $(FATFS_CONTENTS_PATH)

bootloader: firmware $(BOOTLOADER_FILENAME)
	cp $(BOOTLOADER_FILENAME) $(call BUILDBIN,bootloader)

partitiontable: firmware $(PARTITIONTABLE_FILENAME)
	cp $(PARTITIONTABLE_FILENAME) $(call BUILDBIN,partitiontable)

main: firmware $(MAIN_FILENAME)
	cp $(MAIN_FILENAME) $(call BUILDBIN,$(MAIN_PARTITION))

otadata: firmware $(OTADATA_FILENAME)
	cp $(OTADATA_FILENAME) $(call BUILDBIN,$(OTADATA_PARTITION))

phyinitdata: firmware $(PHYINITDATA_FILENAME)
	cp $(PHYINITDATA_FILENAME) $(call BUILDBIN,$(PHYINITDATA_PARTITION))

flashargs: bootloader partitiontable main otadata phyinitdata appfs fatfs  
	@echo "--flash_mode dio --flash_freq 80m --flash_size 16MB" > $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(BOOTLOADER_ADDRESS) $(call BUILDBIN,bootloader)" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(PARTITIONTABLE_ADDRESS) $(call BUILDBIN,partitiontable)" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(MAIN_PARTITION)) $(call BUILDBIN,$(MAIN_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(OTADATA_PARTITION)) $(call BUILDBIN,$(OTADATA_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(PHYINITDATA_PARTITION)) $(call BUILDBIN,$(PHYINITDATA_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(APPFS_PARTITION)) $(call BUILDBIN,$(APPFS_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(FATFS_PARTITION)) $(call BUILDBIN,$(FATFS_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo ""
	@echo "---------------------------------------------------"
	@echo "Flash data is collected in $(BUILD_DIR)/ directory."
	@echo "To flash, call:"
	@echo "esptool.py -p <port> -b <baudrate> write_flash @$(BUILD_DIR)/$(FLASHARGS_FILE)"
	@echo "---------------------------------------------------"

clean:
	-rm -f $(BUILD_DIR)/* 

