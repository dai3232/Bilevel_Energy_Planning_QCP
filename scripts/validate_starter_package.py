#!/usr/bin/env python3
from __future__ import annotations
import csv
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    'AGENTS.md','README_从这里开始.md','交给Codex的首次任务.md','CURRENT_STAGE.md',
    'docs/00_用户确认的模型口径_v1.0.md','docs/02_最终模型合同_v1.0.md',
    'inputs/raw/基础参数.xlsx','inputs/raw/输入数据.xlsx',
    'references/controlled/风光水火储新型递推降阶解耦算法_完整推导与验证.docx',
    'stages/stage_0/AGENTS.md','stages/stage_0/阶段0_长任务.md','stages/stage_0/阶段0_验收矩阵.csv',
]

def sha256(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):
            h.update(b)
    return h.hexdigest()

errors=[]
for rel in REQUIRED:
    if not (ROOT/rel).exists():
        errors.append(f'MISSING {rel}')

hash_csv=ROOT/'inputs/数据文件清单与SHA256.csv'
if hash_csv.exists():
    with hash_csv.open(encoding='utf-8-sig',newline='') as f:
        for row in csv.DictReader(f):
            p=ROOT/'inputs/raw'/row['文件名']
            if not p.exists():
                errors.append(f'MISSING INPUT {p}')
            elif sha256(p)!=row['SHA256']:
                errors.append(f'HASH MISMATCH {p}')
else:
    errors.append('MISSING inputs/数据文件清单与SHA256.csv')

stage_dirs=sorted((ROOT/'stages').glob('stage_*'))
for d in stage_dirs:
    if not (d/'AGENTS.md').exists():
        errors.append(f'MISSING {d.relative_to(ROOT)}/AGENTS.md')
    if not list(d.glob('*_长任务.md')):
        errors.append(f'MISSING long task in {d.relative_to(ROOT)}')
    if not list(d.glob('*_验收矩阵.csv')):
        errors.append(f'MISSING acceptance matrix in {d.relative_to(ROOT)}')

result={'root':str(ROOT),'stage_count':len(stage_dirs),'errors':errors,'status':'PASS' if not errors else 'FAIL'}
print(json.dumps(result,ensure_ascii=False,indent=2))
sys.exit(0 if not errors else 1)
