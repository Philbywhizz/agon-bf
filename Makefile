# ----------------
# Makefile Options
# ----------------

NAME			= projectname
EZ80ASM			= ez80asm
EZ80ASM_FLAGS		= -x -l -s
FAB_AGON_EMU_DIR	= ~/Agon/fab-agon-emulator
FAB_AGON_EMU		= $(FAB_AGON_EMU_DIR)/fab-agon-emulator
FAB_AGON_EMU_MOS	= $(FAB_AGON_EMU_DIR)/firmware/mos_console8.bin
FAB_AGON_EMU_VDP	= $(FAB_AGON_EMU_DIR)/firmware/vdp_console8.so
FAB_AGON_EMU_FLAGS	= --vdp $(FAB_AGON_EMU_VDP) --mos $(FAB_AGON_EMU_MOS) --sdcard bin
GIT_INFO		:= $(shell git describe --always --tags)

default: all

all:
	@echo "Building project..."
	mkdir -p bin
	$(EZ80ASM) $(EZ80ASM_FLAGS) src/$(NAME).asm
	mv src/$(NAME).bin bin/$(NAME).bin

package: all
	@echo "Packaging project..."
	mkdir -p release
	cp README.md release/
	cp bin/$(NAME).bin release/
	cd release && zip -r $(NAME)-$(GIT_INFO).zip *
	rm -fr release/README.md release/$(NAME).bin

clean:
	@echo "Cleaning project..."
	rm -fr bin
	rm -fr release
	rm -fr src/*.bin
	rm -fr src/*.lst
	rm -fr src/*.symbols

run:
	@echo "Launching emulator..."
	$(FAB_AGON_EMU) $(FAB_AGON_EMU_FLAGS)