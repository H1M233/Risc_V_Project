#include <bits/stdc++.h>

using namespace std;

int32_t software_test(int32_t n){
    int32_t ans = 0;
    for (int32_t i = 0; i < n; i++){
        ans += (13 * i) + (i % 7) + (i / -3);
    }
    return ans;
}

int main(){
    int32_t input = 0x186A0;
    int32_t output = software_test(input);

    cout << hex << output;
}