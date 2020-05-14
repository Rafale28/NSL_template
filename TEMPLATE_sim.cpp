#include <stdio.h>
#include <iostream>

#include <verilated_vcd_c.h>
#include <verilated.h>
#include "debug/obj_dir/VTEMPLATE.h"

using namespace std;

VTEMPLATE *nsltemp_i;

unsigned long int pc;

double sc_time_stamp(){
	return pc;
}

int time_counter = 0;
void init(VerilatedVcdC* tfp){
	nsltemp_i->m_clock=0;
	nsltemp_i->p_reset=0;
	nsltemp_i->eval();
	tfp->dump(time_counter++);  // 波形ダンプ用の記述を追加
	nsltemp_i->m_clock=1;
	nsltemp_i->p_reset=1;
	nsltemp_i->eval();
	tfp->dump(time_counter++);  // 波形ダンプ用の記述を追加
	nsltemp_i->m_clock=0;
	nsltemp_i->p_reset=0;
	nsltemp_i->eval();
	tfp->dump(time_counter++);  // 波形ダンプ用の記述を追加
	pc=0;
}

void falling_clock(VerilatedVcdC* tfp){
	nsltemp_i->m_clock=0;
	nsltemp_i->p_reset=1;
	nsltemp_i->eval();
	tfp->dump(time_counter++);  // 波形ダンプ用の記述を追加
}

void rising_clock(VerilatedVcdC* tfp){
	nsltemp_i->m_clock=1;
	pc++;
	nsltemp_i->eval();
	tfp->dump(time_counter++);  // 波形ダンプ用の記述を追加
}

int main(int argv,char *argc[]){
	int i=0;

	nsltemp_i = new VTEMPLATE();
	// -- ここから
  	// Trace DUMP ON
  	Verilated::traceEverOn(true);
  	VerilatedVcdC* tfp = new VerilatedVcdC;

  	//nsltemp_i->trace(tfp, 100);  // Trace 100 levels of hierarchy
  	nsltemp_i->trace(tfp, 1000);  // Trace 100 levels of hierarchy
  	tfp->open("TEMPLATE.vcd");
  	// -- ここまで
	init(tfp);

	while(i<=0xffff){
		falling_clock(tfp);
		//input
		nsltemp_i->exe=1;
		rising_clock(tfp);
		//output
		printf("%x\n",i,nsltemp_i->reg_out);
		i++;
	}
	nsltemp_i->final();
  	tfp->close(); 
	return 0;
}

