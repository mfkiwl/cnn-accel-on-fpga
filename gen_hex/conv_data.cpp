#include <iostream>
#include <fstream>
#include <stdlib.h>
#include <sstream>
#include <cstdint>
#include <stdint.h>
#include <vector>
#include <cmath>
#include <iomanip>

// Parameters of a tile
#define N 32
#define M 64
#define R 32
#define C 32
#define Tn 8
#define Tm 8
#define Tr 16
#define Tc 8
#define K 5
#define S 2
#define X 4
#define Y 4

void init(std::vector<std::vector<std::vector<float> > > &array, const float &val);
void init(std::vector<std::vector<std::vector<std::vector<float> > > > &array, const float &val);
void genHexFile(const std::string &fName, float* const ptr, const int &Num);
void genDecFile(const std::string &fName, float* const ptr, const int &Num);

void arrayResize(std::vector<std::vector<std::vector<float> > > &array, const int &d2, const int &d1, const int &d0);
void arrayResize(std::vector<std::vector<std::vector<std::vector<float> > > > &array, const int &d3, const int &d2, const int &d1, const int &d0);

void simConvTile(
        const std::vector<std::vector<std::vector<float> > > &in_fm, 
        const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
        std::vector<std::vector<std::vector<float> > > &out_fm
        );

void simConv(
        const std::vector<std::vector<std::vector<float> > > &in_fm, 
        const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
        std::vector<std::vector<std::vector<float> > > &out_fm
        );

void goldConv(
        const std::vector<std::vector<std::vector<float> > > &in_fm, 
        const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
        std::vector<std::vector<std::vector<float> > > &out_fm
        );

void resultCheck(
        const std::vector<std::vector<std::vector<float> > > &out_fm0, 
        const std::vector<std::vector<std::vector<float> > > &out_fm1
        );

std::string fp2Hex(float data);

class TileCord{

    int n;
    int m;
    int row;
    int col;

    public:
    TileCord(int n_, int m_, int row_, int col_);

    void fetch(
            std::vector<std::vector<std::vector<float> > > &in_fm_tile, 
            std::vector<std::vector<std::vector<std::vector<float> > > > &weight_tile, 
            std::vector<std::vector<std::vector<float> > > &out_fm_tile,
            const std::vector<std::vector<std::vector<float> > > &in_fm, 
            const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
            const std::vector<std::vector<std::vector<float> > > &out_fm
            );

    void write_back(
            const std::vector<std::vector<std::vector<float> > > &out_fm_tile, 
            std::vector<std::vector<std::vector<float> > > &out_fm
            );

    void update_cord();

};

void arrayResize(std::vector<std::vector<std::vector<float> > > &array, const int &d2, const int &d1, const int &d0){

    array.resize(d2);
    for(int i = 0; i < d2; i++){
        array[i].resize(d1);
        for(int j = 0; j < d1; j++){
            array[i][j].resize(d0);
            for(int k = 0; k < d0; k++){
                array[i][j][k] = 0;
            }
        }
    }

}


void arrayResize(std::vector<std::vector<std::vector<std::vector<float> > > > &array, 
        const int &d3, const int &d2, const int &d1, const int &d0){

    array.resize(d3);
    for(int i = 0; i < d3; i++){
        array[i].resize(d2);
        for(int j = 0; j < d2; j++){
            array[i][j].resize(d1);
            for(int k = 0; k < d1; k++){
                array[i][j][k].resize(d0);
                for(int p = 0; p < d0; p++){
                    array[i][j][k][p] = 0;
                }
            }
        }
    }

}


TileCord::TileCord(int n_, int m_, int row_, int col_){
    n = n_;
    m = m_;
    row = row_;
    col = col_;
}

void TileCord::fetch(
            std::vector<std::vector<std::vector<float> > > &in_fm_tile, 
            std::vector<std::vector<std::vector<std::vector<float> > > > &weight_tile, 
            std::vector<std::vector<std::vector<float> > > &out_fm_tile,
            const std::vector<std::vector<std::vector<float> > > &in_fm, 
            const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
            const std::vector<std::vector<std::vector<float> > > &out_fm
        ){

    // load in_fm_tile
    for(int tm = 0; tm < Tm; tm++){
        for(int tr = 0; tr < Tr; tr++){
            for(int tc = 0; tc < Tc; tc++){
                if(m + tm < M && row + tr < R && col + tc < C){
                    in_fm_tile[tm][tr][tc] = in_fm[m + tm][row + tr][col + tc];
                }
                else{
                    in_fm_tile[tm][tr][tc] = 0;
                }
            }
        }
    }

    // load weight
    for(int tn = 0; tn < Tn; tn++){
        for(int tm = 0; tm < Tm; tm++){
            for(int i = 0; i < K; i++){
                for(int j = 0; j < K; j++){
                    if(n + tn < N && m + tm < M){
                        weight_tile[tn][tm][i][j] = weight[n + tn][m + tm][i][j];
                    }
                    else{
                        weight_tile[tn][tm][i][j] = 0;
                    }
                }
            }
        }
    }

    // load out_fm temporary or initial data
    for(int tn = 0; tn < Tn; tn++){
        for(int tr = 0; tr < Tr; tr++){
            for(int tc = 0; tc < Tc; tc++){
                if(n + tn < N && row + tr < R && col + tc < C){
                    out_fm_tile[tn][tr][tc] = out_fm[n + tn][row + tr][col + tc];
                }
                else{
                    out_fm_tile[tn][tr][tc] = 0;
                }
            }
        }
    }

}

void TileCord::write_back(
            const std::vector<std::vector<std::vector<float> > > &out_fm_tile, 
            std::vector<std::vector<std::vector<float> > > &out_fm
        ){

    int row_step = ((Tr + S - K)/S) * S;
    int col_step = ((Tc + S - K)/S) * S;
    int R_step = ((R + S - K)/S) * S;
    int C_step = ((C + S - K)/S) * S;
    for(int tn = 0; tn < Tn; tn++){
        for(int tr = 0; tr < row_step; tr++){
            for(int tc = 0; tc < col_step; tc++){
                if(n + tn < N && row + tr < R_step && col + tc < C_step){
                    out_fm[n + tn][row + tr][col + tc] = out_fm_tile[tn][tr][tc];
                }
                else{
                    // DO NOT write back these meaningless data
                }
            }
        }
    }

}

void TileCord::update_cord(){

    int row_step = ((Tr + S - K)/S) * S;
    int col_step = ((Tc + S - K)/S) * S;

    int R_step = ((R + S - K)/S) * S;
    int C_step = ((C + S - K)/S) * S;

    if((col + Tc) < C_step){
        col = col + col_step;
    }
    else {
        col = 0;
    }

    if((row + Tr) < R_step && (col + Tc) < C_step){
        row = row;
    }
    else if((row + Tr) < R_step && (col + Tc) >= C_step){
        row = row + row_step;
    }
    else{
        row = 0;
    }

    if((row + Tr) < R_step || (col + Tc) < C_step){
        m = m;
    }
    else if((row + Tr) >= R_step && (col + Tc) >= C_step && (m + Tm <= (M - 1))){
        m = m + Tm;
    }
    else{
        m = 0;
    }

    if((row + Tr) < R_step || (col + Tc) < C_step || (m + Tm) <= (M - 1)){
        n = n;
    }
    else if((row + Tr) >= R_step && (col + Tc) >= C_step && (m + Tm) > (M - 1) && (n + Tn) <= (N - 1)){
        n = n + Tn;
    }
    else{
        n = 0;
    }

}

int main(int argc, char* argv[]) {

    std::cout << "program starts ... " << std::endl;
    std::cout.precision(8);

    // CNN io
    std::vector<std::vector<std::vector<float> > > in_fm;
    std::vector<std::vector<std::vector<std::vector<float> > > > weight;
    std::vector<std::vector<std::vector<float> > > out_fm0;
    std::vector<std::vector<std::vector<float> > > out_fm1;

    //Resize the arrays
    arrayResize(in_fm, M, R, C);
    arrayResize(weight, N, M, K, K);
    arrayResize(out_fm0, N, R, C);
    arrayResize(out_fm1, N, R, C);

    // Initialize the io data
    std::cout << "io initialization starts ... " << std::endl;
    init(in_fm, 0.5);
    init(weight, 0.01);
    init(out_fm0, 0.02);
    init(out_fm1, 0.02);

    // write initial data to files
    std::cout << "writing initial data to files ..." << std::endl;
    genHexFile("./dump/in_fm.txt", &in_fm[0][0][0], M * R * C);
    genHexFile("./dump/weight.txt", &weight[0][0][0][0], N * M * K * K);
    genHexFile("./dump/out_fm_init.txt", &out_fm0[0][0][0], N * R * C);

    // Golden model
    std::cout << "calculating golden model ... " << std::endl;
    goldConv(in_fm, weight, out_fm0);

    // Sim model
    std::cout << "calculating using sim model ... " << std::endl;
    simConv(in_fm, weight, out_fm1);

    // Check the result
    std::cout << "result comparison ..." << std::endl;
    resultCheck(out_fm0, out_fm1);

    std::cout << "End of the model verification. " << std::endl;

}

// Check if the tiling based design produces correct result.
void resultCheck(
        const std::vector<std::vector<std::vector<float> > > &out_fm0, 
        const std::vector<std::vector<std::vector<float> > > &out_fm1
        ){

    for(int to = 0; to < N; to++){
        for (int trr = 0; trr < R; trr++){
            for(int tcc = 0; tcc < C; tcc++){
                float sub = out_fm0[to][trr][tcc] - out_fm1[to][trr][tcc];
                if(out_fm0[to][trr][tcc] != 0){
                    sub = sub/out_fm0[to][trr][tcc];
                }
                if(abs(sub) > 0.00001 ){
                    std::cout << "diff_out_fm[" << to <<"][" << trr << "][" << tcc << "] = " << sub;
                    std::cout << " " << out_fm0[to][trr][tcc] << " " << out_fm1[to][trr][tcc] << std::endl;
                }
            }
        }
    }

}

void simConv(
         const std::vector<std::vector<std::vector<float> > > &in_fm, 
         const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
         std::vector<std::vector<std::vector<float> > > &out_fm){

    int row_step = ((Tr + S - K)/S) * S;
    int col_step = ((Tc + S - K)/S) * S;
    int R_step = ((R + S - K)/S) * S;
    int C_step = ((C + S - K)/S) * S;

    // tile io
    std::vector<std::vector<std::vector<float> > > in_fm_tile;
    std::vector<std::vector<std::vector<std::vector<float> > > > weight_tile;
    std::vector<std::vector<std::vector<float> > > out_fm_tile;

    arrayResize(in_fm_tile, Tm, Tr, Tc);
    arrayResize(weight_tile, Tn, Tm, Tr, Tc);
    arrayResize(out_fm_tile, Tn, Tr, Tc);

    for(int tn = 0; tn < N; tn = tn + Tn){
        for(int tm = 0; tm < M; tm = tm + Tm){
            for (int tr = 0; tr < R_step; tr = tr + row_step){
                for (int tc = 0; tc < C_step; tc = tc + col_step){
                    TileCord base_cord(tn, tm, tr, tc); 
                    base_cord.fetch(in_fm_tile, weight_tile, out_fm_tile, in_fm, weight, out_fm);
                    simConvTile(in_fm_tile, weight_tile, out_fm_tile);
                    base_cord.write_back(out_fm_tile, out_fm);
                    base_cord.update_cord();
                }
            }
        }
    }

    genHexFile("./dump/out_fm_sim.txt", &out_fm[0][0][0], N * R * C);
    genDecFile("./dump/dec_out_fm_sim.txt", &out_fm[0][0][0], N * R * C);

}

void simConvTile(
        const std::vector<std::vector<std::vector<float> > > &in_fm, 
        const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
        std::vector<std::vector<std::vector<float> > > &out_fm
        ){

    int row_step = ((Tr + S - K)/S) * S;
    int col_step = ((Tc + S - K)/S) * S;

    // First slice layer
    for(int to = 0; to < Tn; to = to + 4){
        for(int ti = 0; ti < Tm; ti = ti + 4){
            for(int trr = 0; trr < row_step; trr = trr + S){
                for(int tcc = 0; tcc < col_step; tcc = tcc + S){
                    for(int i = 0; i < K; i++){
                        for(int j = 0; j < K; j++){

                            //Data path 0
                            float fmul0 = in_fm[ti][trr+i][tcc+j] * weight[to][ti][i][j];
                            float fmul1 = in_fm[ti+1][trr+i][tcc+j] * weight[to][ti+1][i][j];
                            float fmul2 = in_fm[ti+2][trr+i][tcc+j] * weight[to][ti+2][i][j];
                            float fmul3 = in_fm[ti+3][trr+i][tcc+j] * weight[to][ti+3][i][j];
                            float fadd_L0_0 = fmul0 + fmul1;
                            float fadd_L0_1 = fmul2 + fmul3;
                            float fadd_top = fadd_L0_0 + fadd_L0_1;
                            out_fm[to][trr][tcc] += fadd_top;

                            //Data path 1
                            fmul0 = in_fm[ti][trr+i][tcc+j] * weight[to+1][ti][i][j];
                            fmul1 = in_fm[ti+1][trr+i][tcc+j] * weight[to+1][ti+1][i][j];
                            fmul2 = in_fm[ti+2][trr+i][tcc+j] * weight[to+1][ti+2][i][j];
                            fmul3 = in_fm[ti+3][trr+i][tcc+j] * weight[to+1][ti+3][i][j];
                            fadd_L0_0 = fmul0 + fmul1;
                            fadd_L0_1 = fmul2 + fmul3;
                            fadd_top = fadd_L0_0 + fadd_L0_1;
                            out_fm[to+1][trr][tcc] += fadd_top;

                            //Data path 2
                            fmul0 = in_fm[ti][trr+i][tcc+j] * weight[to+2][ti][i][j];
                            fmul1 = in_fm[ti+1][trr+i][tcc+j] * weight[to+2][ti+1][i][j];
                            fmul2 = in_fm[ti+2][trr+i][tcc+j] * weight[to+2][ti+2][i][j];
                            fmul3 = in_fm[ti+3][trr+i][tcc+j] * weight[to+2][ti+3][i][j];
                            fadd_L0_0 = fmul0 + fmul1;
                            fadd_L0_1 = fmul2 + fmul3;
                            fadd_top = fadd_L0_0 + fadd_L0_1;
                            out_fm[to+2][trr][tcc] += fadd_top;

                            //Data path 3
                            fmul0 = in_fm[ti][trr+i][tcc+j] * weight[to+3][ti][i][j];
                            fmul1 = in_fm[ti+1][trr+i][tcc+j] * weight[to+3][ti+1][i][j];
                            fmul2 = in_fm[ti+2][trr+i][tcc+j] * weight[to+3][ti+2][i][j];
                            fmul3 = in_fm[ti+3][trr+i][tcc+j] * weight[to+3][ti+3][i][j];
                            fadd_L0_0 = fmul0 + fmul1;
                            fadd_L0_1 = fmul2 + fmul3;
                            fadd_top = fadd_L0_0 + fadd_L0_1;
                            out_fm[to+3][trr][tcc] += fadd_top;

                        }
                    }
                    //std::cout << "ti= " << ti << " out_fm["<< to << "][" << trr << "][" << tcc << "] = " << fp2Hex(out_fm[to+3][trr][tcc]) << std::endl;
                }
            }
        }
        //std::cout << " ----------------------------- " << std::endl;
    }
}

void goldConv(
        const std::vector<std::vector<std::vector<float> > > &in_fm, 
        const std::vector<std::vector<std::vector<std::vector<float> > > > &weight, 
        std::vector<std::vector<std::vector<float> > > &out_fm
        ){
    
    int R_step = ((R + S - K)/S) * S;
    int C_step = ((C + S - K)/S) * S;

    //Perform the convolution
    for(int to = 0; to < N; to++){
        for(int ti = 0; ti < M; ti++){
            for(int trr = 0; trr < R_step; trr = trr + S){
                for(int tcc = 0; tcc < C_step; tcc = tcc + S){
                    for(int i = 0; i < K; i++){
                        for(int j = 0; j < K; j++){
                            out_fm[to][trr][tcc] += in_fm[ti][trr+i][tcc+j] * weight[to][ti][i][j];
                        }
                    }
                }
            }
        }
    } 

    genHexFile("./dump/out_fm_gold.txt", &out_fm[0][0][0], N * R * C);
    genDecFile("./dump/dec_out_fm_gold.txt", &out_fm[0][0][0], N * R * C);

} 


void genDecFile(const std::string &fName, float* const ptr, const int &Num){
    std::ofstream fhandle (fName.c_str());
    if(fhandle.is_open()){
        for (int i = 0; i < Num; i++){
            fhandle << *(ptr + i) << std::endl; 
        }
    }
    fhandle.close();
}


void genHexFile(const std::string &fName, float* const ptr, const int &Num){
    std::ofstream fhandle (fName.c_str());
    if(fhandle.is_open()){
        for (int i = 0; i < Num; i++){
            union {float fval; uint32_t ival;};
            fval = *(ptr + i);

            std::ostringstream oss;
            oss << std::hex << std::uppercase << ival;
            fhandle << oss.str() << std::endl; 
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

void init(std::vector<std::vector<std::vector<float> > > &array, const float &val){

    int d2 = array.size();
    int d1 = array[0].size();
    int d0 = array[0][0].size();
    int id = 0;
    for(int i =0; i< d2; i++){
        for(int j = 0; j < d1; j++){
            for(int k = 0; k < d0; k++){
                array[i][j][k] = val + 0.02 * id;
                id++;
            }
        }
    }

}

void init(std::vector<std::vector<std::vector<std::vector<float> > > > &array, const float &val){

    int d3 = array.size();
    int d2 = array[0].size();
    int d1 = array[0][0].size();
    int d0 = array[0][0][0].size();
    int id = 0;
    for(int i =0; i< d3; i++){
        for(int j = 0; j < d2; j++){
            for(int k = 0; k < d1; k++){
                for(int p = 0; p < d0; p++){
                    array[i][j][k][p] = val + 0.02 * id;
                    id++;
                }
            }
        }
    }

}

