#include <iostream>

int main()
{
    int steps = 3;
    float step{0.5};
    float cursor{0};
    
    for(int j=0; j<steps; j++) 
    {
        std::cout << cursor << " ";
        cursor += step;
    }
    std::cout << std::endl;
    
    steps = 2;
    step *= 0.5f;
    for(int iterations=0; iterations<10; iterations++)
    {
        int stepsDoubled = steps*2;
        for(int i=1; i<stepsDoubled; i+=2)
        {
            cursor = i*step; 
            std::cout << cursor << " ";
        }
        std::cout << std::endl;
        steps <<= 1;
        step *=0.5f;
    }
}
