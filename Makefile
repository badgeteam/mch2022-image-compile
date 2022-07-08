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
PARTITION_OFFSET = $$($(SOURCE_FW_IDF) && $(PARTINFO_PY) -f $(PATITION_TABLE_PATH) get_partition_info --partition-name $(1) --info offset)
PARTITION_SIZE = $$($(SOURCE_FW_IDF) && $(PARTINFO_PY) -f $(PATITION_TABLE_PATH) get_partition_info --partition-name $(1) --info size)
SOURCE_FW_IDF = . "$(FIRMWARE_IDF_PATH)/export.sh" > /dev/null 2>/dev/null
BUILDBINNAME = $(1).bin
BUILDBINPATH = $(BUILD_DIR)/$(1).bin
DECIMAL = $$(printf "%d" $(1))

.PHONY: firmware sponsorapp appfs fatfs bootloader partitiontable main otadata phyinitdata flashargs singlebin clean 

all: flashargs

firmware:
	@echo ">>> Building firmware"
	cd $(FIRMWARE_REPO_PATH) && make prepare && make build

sponsorapp:
	@echo ">>> Building sponsor app"
	$(SOURCE_FW_IDF) &&	cd $(SPONSORAPP_MAKE_PATH) && idf.py build

appfs: sponsorapp
	@echo ">>> Generating AppFS"
	mkdir -p $(BUILD_DIR)
	$(SOURCE_FW_IDF) &&	python $(APPFS_GEN_PY) $(call DECIMAL,$(call PARTITION_SIZE,$(APPFS_PARTITION))) $(call BUILDBINPATH,$(APPFS_PARTITION))
	$(SOURCE_FW_IDF) &&	python $(APPFS_ADD_PY) $(call BUILDBINPATH,$(APPFS_PARTITION)) $(SPONSORAPP_BIN) sponsors "Sponsor Slideshow" 1

fatfs:
	@echo ">>> Generating FatFS"
	mkdir -p $(BUILD_DIR)
	$(SOURCE_FW_IDF) && $(FATGEN_PY) $(FATFS_GEN_FLAGS) --partition_size $(call PARTITION_SIZE,$(FATFS_PARTITION)) --output_file $(call BUILDBINPATH,$(FATFS_PARTITION)) $(FATFS_CONTENTS_PATH)

bootloader: firmware $(BOOTLOADER_FILENAME)
	@echo ">>> Assembling bootloader"
	mkdir -p $(BUILD_DIR)
	cp $(BOOTLOADER_FILENAME) $(call BUILDBINPATH,bootloader)

partitiontable: firmware $(PARTITIONTABLE_FILENAME)
	@echo ">>> Assembling partition table"
	mkdir -p $(BUILD_DIR)
	cp $(PARTITIONTABLE_FILENAME) $(call BUILDBINPATH,partitiontable)

main: firmware $(MAIN_FILENAME)
	@echo ">>> Assembling firmware partition"
	mkdir -p $(BUILD_DIR)
	cp $(MAIN_FILENAME) $(call BUILDBINPATH,$(MAIN_PARTITION))

otadata: firmware $(OTADATA_FILENAME)
	@echo ">>> Assembling otadata partition"
	mkdir -p $(BUILD_DIR)
	cp $(OTADATA_FILENAME) $(call BUILDBINPATH,$(OTADATA_PARTITION))

phyinitdata: firmware $(PHYINITDATA_FILENAME)
	@echo ">>> Assembling PHY init data partition"
	mkdir -p $(BUILD_DIR)
	cp $(PHYINITDATA_FILENAME) $(call BUILDBINPATH,$(PHYINITDATA_PARTITION))

flashargs: bootloader partitiontable main otadata phyinitdata appfs fatfs  
	@echo ">>> Generating flashargs"
	mkdir -p $(BUILD_DIR)
	@echo "--flash_mode dio --flash_freq 80m --flash_size 16MB" > $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(BOOTLOADER_ADDRESS) $(call BUILDBINNAME,bootloader)" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(PARTITIONTABLE_ADDRESS) $(call BUILDBINNAME,partitiontable)" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(MAIN_PARTITION)) $(call BUILDBINNAME,$(MAIN_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(OTADATA_PARTITION)) $(call BUILDBINNAME,$(OTADATA_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(PHYINITDATA_PARTITION)) $(call BUILDBINNAME,$(PHYINITDATA_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(APPFS_PARTITION)) $(call BUILDBINNAME,$(APPFS_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo "$(call PARTITION_OFFSET,$(FATFS_PARTITION)) $(call BUILDBINNAME,$(FATFS_PARTITION))" >> $(BUILD_DIR)/$(FLASHARGS_FILE)
	@echo ""
	@echo "-------------------------------------------------------------"
	@echo "All programming data is collected in $(BUILD_DIR)/ directory."
	@echo "This directory can be copied to other places or machines."
	@echo "To flash, setup ESP IDF environment and call:"
	@echo "cd $(BUILD_DIR) && esptool.py --chip ESP32 --port <port> --baud <baudrate> write_flash @$(FLASHARGS_FILE)"
	@echo "To make a full factory reset including NVS erase, use write_flash -e instead of write_flash"
	@echo "-------------------------------------------------------------"

singlebin: flashargs
	@echo ">>> Merging binaries into single blob"
	$(SOURCE_FW_IDF) && cd $(BUILD_DIR) && esptool.py --chip ESP32 merge_bin -o singlebin.bin @flashargs
	@echo "-------------------------------------------------------------"
	@echo "Images have been merged to a single file $(BUILD_DIR)/singlebin.bin."
	@echo "To flash, setup ESP IDF environment and call:"
	@echo "cd $(BUILD_DIR) && esptool.py --chip ESP32 --port <port> --baud <baudrate> write_flash --flash_mode dio --flash_freq 80m --flash_size 16MB 0x0 singlebin.bin"
	@echo "-------------------------------------------------------------"

clean:
	-rm -f $(BUILD_DIR)/* 

