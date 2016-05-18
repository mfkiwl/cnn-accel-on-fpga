#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <sstream>
#include <cstdint>
#include <stdint.h>
#include <vector>
#include <cmath>

// Parameters of a tile
#define Tn 16
#define Tm 16
#define Tr 64
#define Tc 16
#define K 3
#define S 1

void init(float* const ptr, const int &Num, const float &base);
void genHexFile(const std::string &fName, float* const ptr, const int &Num);
std::string fp2Hex(float data);

int main(int argc, char* argv[]) {
    float in_fm[Tm][Tr][Tc];
    float weight[Tn][Tm][K][K];
    float out_fm[Tn][Tr][Tc];

    // Initialize the io data
    init(&in_fm[0][0][0], Tm*Tr*Tc, 0.5);
    init(&weight[0][0][0][0], Tn*Tm*K*K, 0.01);
    init(&out_fm[0][0][0], Tn*Tr*Tc, 0.02);

    genHexFile("in_fm.txt", &in_fm[0][0][0], Tm*Tr*Tc);
    genHexFile("weight.txt", &weight[0][0][0][0], Tn*Tm*K*K);
    genHexFile("out_fm_init.txt", &out_fm[0][0][0], Tn*Tr*Tc);

    //Perform the convolution
    for(int to = 0; to < Tn; to++){
        for(int ti = 0; ti < Tm; ti++){
            for(int trr = 0; trr < Tr; trr = trr + S){
                for(int tcc = 0; tcc < Tc; tcc = tcc + S){
                    for(int i = 0; i < K; i++){
                        for(int j = 0; j < K; j++){
                            out_fm[to][trr][tcc] += in_fm[ti][trr+i][tcc+j] * weight[to][ti][i][j];
                        }
                    }
                }
            }
        }
    }

    genHexFile("out_fm.txt", &out_fm[0][0][0], Tn*Tr*Tc);

}


void init(float* const ptr, const int &Num, const float &base){
    for(int i=0; i<Num; i++){
        *(ptr+i) = base + 0.001 * i;
    }
}

void genHexFile(const std::string &fName, float* const ptr, const int &Num){
    std::ofstream fhandle (fName.c_str());
    if(fhandle.is_open()){
        int d = 0;
        for (int i=0; i < Num; i++){
            union {float fval; uint32_t ival;};
            fval = *(ptr + i);

            std::ostringstream oss;
            oss << std::hex << std::uppercase << ival;
            fhandle << oss.str() << "    "; 
            d++;
            if(d==16){
                fhandle << std::endl;
                d = 0;
            }
        }
    }
    fhandle.close();

}

std::string fp2Hex(float data){
    std::ostringstream oss;
    union {float fval; uint32_t ival;};
    fval = data;
    oss << std::hex << std::uppercase << ival;
    return oss.str();
}