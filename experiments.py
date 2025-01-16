import os, argparse, time, logging
import benchmarks as FazaBenchmarks
from subprocess import check_output
import tempfile
import pandas as pd

def evaluate_psi(
    benchmarks,
    result_dir,
    benchmark_name,
    timeout
):
        results = []    
        
        result_path = os.path.join(result_dir, f"benchmark_{benchmark_name}_psi_{int(time.time())}.csv")

        for _, bench in enumerate(benchmarks):
            bench_i = bench['index']
            start_time = time.time()
            try:
                
                if "psi" not in  bench:
                    raise Exception('Missing input formula')
                if bench['psi']['formula'] is None:
                    raise Exception('N\S')
                
                program_path = os.path.join(result_dir, f"psi_template_bench_{benchmark_name}_{bench_i}.psi")
                
                with open(program_path, 'w') as f:
                        if len(bench['faza']['chi']) == 1:
                            f.write(
                                FazaBenchmarks.PSI_SOLVER_ONE_VAR_TEMPLATE.format(
                                    x_lower_bound = bench['faza']['chi'][0][0],
                                    x_upper_bound = bench['faza']['chi'][0][1],
                                    formula = bench['psi']['formula']
                                )
                            )
                        elif len(bench['faza']['chi']) == 2:
                            f.write(
                                FazaBenchmarks.PSI_SOLVER_TWO_VAR_TEMPLATE.format(
                                    x_lower_bound = bench['faza']['chi'][0][0],
                                    x_upper_bound = bench['faza']['chi'][0][1],
                                    y_lower_bound = bench['faza']['chi'][1][0],
                                    y_upper_bound = bench['faza']['chi'][1][1],
                                    formula = bench['psi']['formula']
                                )
                            )
                        elif len(bench['faza']['chi']) == 3:
                            f.write(
                                FazaBenchmarks.PSI_SOLVER_THREE_VAR_TEMPLATE.format(
                                    x_lower_bound = bench['faza']['chi'][0][0],
                                    x_upper_bound = bench['faza']['chi'][0][1],
                                    y_lower_bound = bench['faza']['chi'][1][0],
                                    y_upper_bound = bench['faza']['chi'][1][1],
                                    z_lower_bound = bench['faza']['chi'][2][0],
                                    z_upper_bound = bench['faza']['chi'][2][1],
                                    formula = bench['psi']['formula']
                                )
                            )
                output = check_output([
                    "timeout", str(timeout),
                    './psi', program_path, '--expectation', '--mathematica']).decode("utf-8").strip().replace('\n', '\t')
                results.append({
                    "bechmark": benchmark_name,
                    "formula": bench['faza']['w'],
                    "bounds": bench['faza']['chi'],
                    "index": bench_i,
                    'output': output,
                    'error': None,
                    "time": time.time()-start_time,
                    'details': []
                })
                logging.info(f"Bench {bench_i} ({bench['faza']['w']}) is done: {output}")
            
            except Exception as e:
                logging.info(f"Bench {bench_i} ({bench['faza']['w']}) is failed: {e}")
                results.append({
                    "bechmark": benchmark_name,
                    "formula": bench['faza']['w'],
                    "bounds": bench['faza']['chi'],
                    "index": bench_i,
                    "output": None,
                    'error': str(e),
                    "time": time.time()-start_time,
                    'details': []
                })      
                
            pd.DataFrame(results).sort_values('index').to_csv(result_path, index=False)
            
    
if __name__ == "__main__":
    
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(
            prog='Faza Integrator',
            description='I am experimenting!'
            )
    
    parser.add_argument("--timeout", type=float, default=10)        
    parser.add_argument("--epsilon", help="Number of workers", type=float, default=50)        
    parser.add_argument("--max-workers", help="Number of workers", type=int, default=1)
    parser.add_argument("--repeat", help="Number of trials", type=int, default=10)
    parser.add_argument('--psi', action='store_true', default=False)
    parser.add_argument('--benchmark', choices=['manual', 'rational', 'sqrt', "rational_sqrt", "rational_2"], default="manual")
    parser.add_argument('--benchmark-path', type=str, help="Path to the benchmark")
    
    
    
    parser.add_argument('--result-dir', type=str, default="experimental_results")
    
    args = parser.parse_args()
    
    
    os.makedirs(args.result_dir, exist_ok=True)


    if args.benchmark == 'manual':
        benchmarks = FazaBenchmarks.selected_benchmark
        args.benchmark = "manual"
    elif args.benchmark == "rational":
        benchmarks = FazaBenchmarks.load_rational_benchmarks(
            args.benchmark_path
        )
    elif args.benchmark == "sqrt":
        benchmarks = FazaBenchmarks.load_sqrt_benchmarks(
            args.benchmark_path
        )
    elif args.benchmark == "rational_sqrt":
        benchmarks = FazaBenchmarks.load_rational_sqrt_benchmarks(
            args.benchmark_path
        )
    elif args.benchmark == "rational_2":
        benchmarks = FazaBenchmarks.load_rational_2_benchmarks(
            args.benchmark_path
        )
    else:
        raise NotImplementedError()

        
    if args.psi:
        evaluate_psi(
            benchmarks=benchmarks,
            result_dir=args.result_dir,
            benchmark_name=args.benchmark,
            timeout=args.timeout
        )
        
        
        
        
