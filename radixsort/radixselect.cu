/**
Divide into 256 element block.

For each block:
- build histogram

**/
// compile with: nvcc -arch=sm_30 radixsort_better.cu -I./cub

#include <iostream>
#include "radixutils.h"

int
main()
{
	using std::cout;
	using std::endl;

    typedef uint32_t data_type;

	const unsigned stride = sizeof(data_type);

	unsigned ct_data = 1000;
	unsigned sz_data = sizeof(data_type) * ct_data;

    const unsigned ct_block = (ct_data + (BUCKET_SIZE-1)) / BUCKET_SIZE;
    cout << "ct_block = " << ct_block << '\n';

	unsigned ct_hist = ct_block * BUCKET_SIZE;
	unsigned sz_hist = sizeof(unsigned) * ct_hist;

    unsigned ct_bucket_total = BUCKET_SIZE;
    unsigned sz_bucket_total = sizeof(unsigned) * ct_bucket_total;

    unsigned sz_indices = sizeof(unsigned)*ct_data;

	data_type *data = new data_type[ct_data];
	unsigned *hist = new unsigned[ct_hist];
    unsigned *bucket_total = new unsigned[ct_bucket_total];

	for (unsigned i=0; i<ct_data; ++i) {
		data[i] = ct_data - i - 1;
	}

    uint8_t *dev_data;
    uint8_t *dev_sorted;
    unsigned *dev_hist;
    unsigned *dev_bucket_total;
    unsigned *dev_indices;

    cudaMalloc(&dev_data, sz_data);
    cudaMalloc(&dev_indices, sz_data);
    cudaMalloc(&dev_sorted, sz_indices);
    cudaMalloc(&dev_hist, sz_hist);
    cudaMalloc(&dev_bucket_total, sz_bucket_total);

    // send data

	cudaMemcpy(dev_data, data, sz_data, cudaMemcpyHostToDevice);
	ASSERT_CUDA_LAST_ERROR();


    // compute

    for (unsigned r=0; r < 4; ++r) {
        unsigned offset = 1;

    	cu_build_histogram<<<ct_block, BUCKET_SIZE>>>(
    		dev_data,
    		dev_hist,
    		stride,
    		offset,
    		ct_data
    	);
    	ASSERT_CUDA_LAST_ERROR();

        cu_scan_histogram<<<BUCKET_SIZE, SCAN_HISTOGRAM_BLOCK_SIZE>>>(
            dev_hist,
            dev_bucket_total,
            ct_block
        );
        ASSERT_CUDA_LAST_ERROR();


        cu_scan_bucket_index<<<1, BUCKET_SIZE>>>(dev_bucket_total);
        ASSERT_CUDA_LAST_ERROR();

        compute_indices(
            dev_data,
            dev_indices,
            dev_hist,
            dev_bucket_total,
            ct_data,
            stride,
            offset,
            ct_block
        );

        cu_scatter<<<ct_block, BUCKET_SIZE>>>(
            dev_data,
            dev_sorted,
            dev_indices,
            ct_data,
            stride
        );

        ASSERT_CUDA_LAST_ERROR();

        cudaMemcpy(dev_data, dev_sorted, sz_data, cudaMemcpyDeviceToDevice);
        ASSERT_CUDA_LAST_ERROR();
    }
    // write back

    cudaMemcpy(data, dev_sorted, sz_data, cudaMemcpyDeviceToHost);
    ASSERT_CUDA_LAST_ERROR();

    cout << "sorted\n";
    for (unsigned i = 0; i < ct_data; ++i) {
        cout << i << ' ' << data[i] << '\n';
        // if(data[i] != i) {
        //     cout << "error at i = " << i << " = " << data[i] << endl;
        //     exit(1);
        // }
    }


	cout << "ok" << endl;
	return 0;
}