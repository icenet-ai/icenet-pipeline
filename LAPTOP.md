## South

python data.py -v -e -o south 2010-01-01 2010-01-31

...

## North

Prepared with data in situ for 2010_01_01 - 2010_01_31

```bash
conda activate icenet2

# No data required, but would've been, most likely
python data.py -v -e -o north 2010-01-01 2010-01-31

# Process
python process.py -v -w 4 -ob 2 -fd 4 -l 2 -sp \
    -ts 2010-01-28 -te 2010-01-31 \
    laptop north 2010-01-01 2010-01-22 2010-01-23 2010-01-27
    
# Generate
python process.py -v -w 4 -ob 2 -fd 4 -l 2 -so -se -sm \
    -ts 2010-01-28 -te 2010-01-31 \
    laptop north 2010-01-01 2010-01-22 2010-01-23 2010-01-27

model_ensemble -n -v ensemble/train_ensemble.yaml dummy

model_ensemble -n -v ensemble/predict_ensemble.yaml dummy
```