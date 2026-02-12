#include <iostream>
#include <iomanip> 

template <typename T>
void test()
{
    T a = 0;
    int count = 8;
    T step = 0.1234;
    
    T b = step*count;

    for(int i=0; i<count; i++)
        a+= step;

    if(a==b) std::cout << "SAME";
    std::cout << std::setprecision(20) << a << std::endl;
    std::cout << std::setprecision(20) << a << std::endl;
}

int main()
{
   test<float>();
   test<double>();
}
