#include <iostream>
#include <chrono>
#include <ctime>
 
int main() 
{
    constexpr int SIZE_X{1000};
    constexpr int SIZE_Y{SIZE_X};

    auto seed{std::time(nullptr)};
    int acc = 0;
    std::chrono::time_point<std::chrono::high_resolution_clock> start;
    std::chrono::time_point<std::chrono::high_resolution_clock> end;
    std::chrono::microseconds duration;
    
    std::srand(seed);
    start = std::chrono::high_resolution_clock::now();
    for(int x=0; x<SIZE_X; x++)
    for(int y=0; y<SIZE_Y; y++)
    {
        int linear = y*SIZE_X + x;
        acc += std::rand() +  x + y + linear;
    }
    end = std::chrono::high_resolution_clock::now();
    duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << "Result: " << acc << " Time: " <<  duration.count() << std::endl;

    acc = 0;
    std::srand(seed);
    start = std::chrono::high_resolution_clock::now();
    for(int i=0; i<SIZE_X*SIZE_Y; i++)
    {
        int x = i%SIZE_X;
        int y = i/SIZE_X;
        acc += std::rand() +  x + y + i;
    }
    end = std::chrono::high_resolution_clock::now();
    duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << "Result: " << acc << " Time: " << duration.count() << std::endl;

}
