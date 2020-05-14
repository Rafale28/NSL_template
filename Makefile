################################################################################
# Makefile : sof file generation using Quartus II
# Usage:
#		make compile for synthesis all files
#       make download for download .sof file to FPGA board
################################################################################

ifndef SRCDIR
SRCDIR	= .
endif
WORKDIR		= $(SRCDIR)/work
DEBUGDIR	= $(SRCDIR)/debug
VPATH		= $(SRCDIR)
ifndef DESIGN
DESIGN		= DE0_CV
endif
TARGET		=
PROJECT		= $(DESIGN)
NSL2VL    	= nsl2vl
NSLSIMFLAGS = -sim -neg_res -I$(SRCDIR)
ifndef SIM
NSLFLAGS  	= -O2 -neg_res -I$(SRCDIR)
else
NSLFLAGS	= $(NSLSIMFLAGS)
endif
MKPROJ		= $(SRCDIR)/mkproj-$(DESIGN).tcl
LBITS		= $(shell getconf LONG_BIT)
ifeq	($(LBITS),64)
	Q2SH		= quartus_sh.exe --64bit
	Q2PGM		= quartus_pgm.exe --64bit
else
	Q2SH		= quartus_sh.exe 
	Q2PGM		= quartus_pgm.exe 
endif
Q2SHOPT		= -fit "fast fit"

CABLE		= "USB-Blaster"
PMODE		= JTAG

VERIOPT		= 
SRCS		= TEMPLATE.nsl
SYNTHSRCS	= $(PROJECT).nsl $(SRCS)
VFILES 		= $(SYNTHSRCS:%.nsl=%.v) 
SIMVFILES	= $(SRCS:%.nsl=%.v)
LIBS		= 
RESULT		= result.txt

IVERILOG	= iverilog.exe
VVP 		= vvp.exe
VERILATOR	= verilator
GTKWAVE		= gtkwave.exe

##################################################################################
#quartus
##################################################################################

all:
	@if [ ! -d $(WORKDIR) ]; then \
		echo mkdir $(WORKDIR); \
		mkdir $(WORKDIR); \
	fi
	( cd $(WORKDIR); make -f ../Makefile SRCDIR=.. compile )

########

.SUFFIXES: .v .nsl

%.v:%.nsl
	$(NSL2VL) $(NSLFLAGS) $< -o $@

$(PROJECT).qsf: $(VFILES) $(LIBS) 
	$(Q2SH) -t $(MKPROJ) $(Q2SHOPT) -project $(PROJECT) $^

$(PROJECT).sof: $(PROJECT).qsf 
	$(Q2SH) --flow compile $(PROJECT)

########

compile: $(PROJECT).sof
	@echo "**** $(PROJECT).fit.summary" | tee -a $(RESULT)
	@cat $(PROJECT).fit.summary | tee -a $(RESULT)
	@echo "**** $(PROJECT).tan.rpt" | tee -a $(RESULT)
#	@grep "Info: Fmax" $(PROJECT).tan.rpt | tee -a $(RESULT)

download: config-n

config: all
	$(Q2PGM) -c $(CABLE) -m $(PMODE) -o "p;$(WORKDIR)/$(PROJECT).sof"
config-n: # without re-compile
	$(Q2PGM) -c $(CABLE) -m $(PMODE) -o "p;$(WORKDIR)/$(PROJECT).sof"

##################################################################################
#iverilog
##################################################################################

%_sim.v: %_sim.nsl
	$(NSL2VL) $(NSLSIMFLAGS) -verisim2 -target $(@:%.v=%) $< -o $@

%.vsim:
	@if [ ! -d $(DEBUGDIR) ]; then \
		echo mkdir $(DEBUGDIR); \
		mkdir $(DEBUGDIR); \
	fi
	( cd $(DEBUGDIR); make -f ../Makefile SIM=1 SRCDIR=.. TARGET=$* gtkwave )

$(TARGET).vvp: $(TARGET)_sim.v $(SIMVFILES)
	$(IVERILOG) -o $@ $^

$(TARGET)_sim.vcd: $(TARGET).vvp
	$(VVP) $<

gtkwave:$(TARGET)_sim.vcd
	$(GTKWAVE) $<

clean:
	rm -rf - $(WORKDIR)
	rm -rf - $(DEBUGDIR)

##################################################################################
#verilator
##################################################################################

%.sim:
	@if [ ! -d $(DEBUGDIR) ]; then \
		echo mkdir $(DEBUGDIR); \
		mkdir $(DEBUGDIR); \
	fi
	( cd $(DEBUGDIR); make -f ../Makefile SRCDIR=.. TARGET=$(@:%.sim=%) V$(@:%.sim=%) )

V$(TARGET).h: $(VFILES) $(TARGET)_sim.cpp
	sed -i -e "s/#1//" *.v
	$(VERILATOR) --trace --trace-params --trace-structs --trace-underscore --cc $(VERIOPT) $(TARGET).v --exe $(SRCDIR)/$(TARGET)_sim.cpp

V$(TARGET): V$(TARGET).h 
	@echo "simulation"
	(cd obj_dir; make -j -f V$(TARGET).mk V$(TARGET) )

%.run:%.sim
	(cd $(DEBUGDIR); time ./obj_dir/V$(@:%.run=%))
	(cd $(DEBUGDIR); pwd; $(GTKWAVE) $(@:%.run=%).vcd)

%.rerun:
	(cd $(DEBUGDIR); time ./obj_dir/V$(@:%.rerun=%))
	(cd $(DEBUGDIR); pwd; $(GTKWAVE) $(@:%.rerun=%).vcd)

##################################################################################