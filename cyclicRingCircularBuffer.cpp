#include <iostream>
#include <vector>

template <typename T> 
class RingBuffer
{ 
    public:     
    RingBuffer(size_t size) : data{std::vector<T>(size)}{}
    friend void operator<<(RingBuffer &buffer, T element){buffer.addElement(element);}
    T operator[](int index){return data[index];}

    private:    
    size_t end{0};
    std::vector<T> data; 
    void addElement(T element) {data[end]=element; end++; end%=data.size();};
};


int main()
{
    int size{3};
    RingBuffer<int> circular(size);
    for(int i=0; i<size; i++)
        circular << i;
    for(int i=0; i<size; i++)
        std::cout << circular[i] << " ";
    std::cout << std::endl;
    circular << 7;
    circular << 42;
    for(int i=0; i<size; i++)
        std::cout << circular[i] << " ";
    std::cout << std::endl;
}
