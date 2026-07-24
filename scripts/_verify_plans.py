#!/usr/bin/env python3
import json
import urllib.request

url = "https://anylang.uz/api/v1/subscription/plans?language=uz_UZ"
with urllib.request.urlopen(url, timeout=30) as r:
    data = json.load(r)
print("period_options", data.get("period_options"))
prem = data["plans"][1]
print("premium periods", prem.get("periods"))
print("yearly_total", prem.get("yearly_total"))
