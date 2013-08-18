#include <iostream>
#include <stdio.h>
#include <inttypes.h>

int main(int argc, char **args)
{
	int32_t long_integer;
	int32_t *ptri = &long_integer;
  uint32_t *ptru;
	float floating_point_single_precision;
  float *ptrf = &floating_point_single_precision;
	double floating_point_double_precision;
  double *ptrd = &floating_point_double_precision;

  if(argc < 2)
  {
    std::cout << "No value specified.\n";
    return -1;
  }

  *ptri = atoi(args[1]);
  *ptrd = atof(args[1]);
  *ptrf = *ptrd;
  ptru = reinterpret_cast<uint32_t*>(ptrf);
  std::cout << "The floating point number " << *ptrf << " translated into hex.\n32bit: " << std::hex << *ptru << "\n";
  ptru = reinterpret_cast<uint32_t*>(ptrd);
  std::cout << "64bit: " << std::hex << *ptru << ", " << std::hex << *(ptru + 1) << "\n";
  std::cout << "The integer " << std::dec << *ptri << " translated into hex: " << std::hex << *ptri << "\n";
  return 0;
}
