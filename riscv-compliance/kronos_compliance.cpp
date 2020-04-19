// Copyright (c) 2020 Sonal Pinto
// SPDX-License-Identifier: Apache-2.0

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <regex>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "kronos_compliance_top.h"

using namespace std;

class Sim {
  private:
    kronos_compliance_top *top;
    VerilatedVcdC* trace;
    int ticks;
    IData sim_end_addr;

  public:
    Sim(string memfile, string sim_end_addr) {
      top = new kronos_compliance_top;
      trace = new VerilatedVcdC;

      ticks = 0;

      // load program into memory
      IData word;
      int i;
      ifstream FILE(memfile.c_str(), ios::binary);
      
      i = 0;
      while(FILE.read((char*)&word, 4)) {
        top->kronos_compliance_top__DOT__u_mem__DOT__MEM[i] = word;
        i++;
      }
      FILE.close();

      // record simulator-end signature
      this->sim_end_addr = stoul(sim_end_addr, nullptr, 16);

      // init inputs
      top->clk = 0;
      top->rstz = 1;
    }

    ~Sim(void) {
      delete top;
      ticks = 0;
    }

    void start_trace(string vcd_file) {
      // init waveform tracer
      Verilated::traceEverOn(true);
      top->trace(trace, 99);
      trace->open(vcd_file.c_str());
    }

    void tick(void) {
      top->clk = 1;
      top->eval();
      trace->dump(ticks);
      ticks++;
      
      top->clk = 0;
      top->eval();
      trace->dump(ticks);
      ticks++;

      trace->flush();
    }

    void reset(void) {
      top->rstz = 0;
      tick();
      top->rstz = 1;
    }

    void stop_trace(void) {
      trace->close();
    }

    int get_ticks(void) {
      return this->ticks;
    }

    bool run(int cycles) {
      bool done = false;

      for (int i=0; i<cycles; i++) {
        tick();

        // The compliance tests writes a "1" to the tohost address to indicate
        // that the test is done.
        if (top->data_ack && top->data_wr_en 
          && top->data_addr == sim_end_addr && top->data_wr_data == 1) {
          done = true;
          break;
        }
      }
    }

    void print_signature(string resfile, string begin, string end) {
      IData begin_addr = stoul(begin, nullptr, 16);
      IData end_addr = stoul(end, nullptr, 16);
      char txt[32];
      IData data;

      // convert byte-address into word address
      begin_addr  = begin_addr >> 2;
      end_addr  = end_addr >> 2;

      ofstream FILE(resfile.c_str());

      for (int i=begin_addr; i<end_addr; i++) {
        data = top->kronos_compliance_top__DOT__u_mem__DOT__MEM[i];
        sprintf(txt, "%08x\n", data);
        FILE << txt;
      }

      FILE.close();
    }
};

int main(int argc, char **argv) {
  string memfile, resfile, nmfile, vcd_file;
  string test_name, begin_signature, end_signature, tohost;

  // ----------------------------------------------------------
  // Parse args for binary and result signature files
  if (argc != 3) {
    cout << "[USAGE]\n";
    cout << "kronos_compliance <PATH/input_program.bin> <PATH/signature.output>\n\n";
    return 1;
  }

  memfile = argv[1];
  resfile = argv[2];

  // Extract test name
  smatch m;
  regex_search(memfile, m, regex("/([^/]+).bin"));
  test_name = m[1];

  // Simulation trace file
  vcd_file = regex_replace(memfile, regex(".bin"), ".vcd");

  // Parse nm file for specific sections
  nmfile = regex_replace(memfile, regex(".bin"), ".nm");

  ifstream file(nmfile);
  string str, buf;
  vector<string> items;
  while (std::getline(file, str)) {
    std::stringstream line(str);
    items.clear();

    while (line >> buf) {
      items.push_back(buf);
    }

    if (items[2] == "begin_signature") {
      begin_signature = items[0];
    } else if (items[2] == "end_signature") {
      end_signature = items[0];
    } else if (items[2] == "tohost") {
      tohost = items[0];
    }
  }
  file.close();

  cout << "Compliance test: " << test_name << endl;
  cout << "Program: " << nmfile << endl;
  cout << "Result: " << resfile << endl;
  cout << "Waveform: " << vcd_file << endl;
  cout << "begin_signature: " << begin_signature << endl;
  cout << "end_signature: " << end_signature << endl;
  cout << "tohost: " << tohost << endl;

  // ----------------------------------------------------------
  // Run simulation
  cout << "\nStarting Sim...\n\n";

  Sim sim(memfile, tohost);

  sim.start_trace(vcd_file);

  sim.reset();
  if(!sim.run(10000)){
    cout << "Simulation Failed\n";
  } else {
    cout << "Simulation OK\n";
    sim.print_signature(resfile, begin_signature, end_signature);
  }

  cout << "Simulation ticks: " << sim.get_ticks() << endl;

  sim.stop_trace();

  cout <<"\n\n";
  return 0;
}
