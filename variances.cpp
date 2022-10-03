#include <iostream>
#include <vector>

float classicVariance(std::vector<float> data)
{
    float mean{0};
    for(const auto val : data)
        mean += val;
    mean /= data.size();
    float var = 0;
    for(const auto val : data)
    {
        float delta = abs(val-mean);
        var += delta*delta;
    }    
    return var/(data.size()-1);
}

float noMeanVariance(std::vector<float> data)
{
    float m{0};
    float m2{0};
    for(auto val : data)
    {
        m2 += val*val;
        m += val;
    }
    return 1.f/(data.size()-1)*( m2 - (1.f/data.size())*m*m );
}

class OnlineVariance
{
    private:
    float n{0};
    float m{0};
    float m2{0};
    
    public:
    void add(float val)
    {
       n++;
       float delta = val-m;
       m += delta/n;
       float newDelta = val - m;
       m2 += delta*newDelta;
    }
    float variance()
    {
        return m2/(n-1);    
    }      
    OnlineVariance& operator+=(const float& rhs){

      add(rhs);
      return *this;
    }
};


int main()
{
std::vector<float> data{1,5,10,3,20,50,255,1};
std::cout << "Classic: " << classicVariance(data) << std::endl;
std::cout << "No mean: " << noMeanVariance(data) << std::endl;
OnlineVariance ov;
for(const auto val : data)
    ov += val;
std::cout << "Online: " << ov.variance() << std::endl;
}
