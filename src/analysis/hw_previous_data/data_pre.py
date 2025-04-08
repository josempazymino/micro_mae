# -*- coding: utf-8 -*-
"""
Created on Wed Oct 23 14:05:53 2024

@author: josem
"""

import pyblp
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

############################
############################

data = pd.read_stata('OTC_DATA.dta')
demo = pd.read_stata('OTC_Demographics.dta')
ivs  = pd.read_stata('OTC_Instruments.dta')
vv   = pd.read_stata('v.dta')

# creo variable market_ids
data['market_ids'] = data['store']*100 + data['week']
# cuantos mercados hay?
nmarket = data.market_ids.nunique()
# 
data['product_ids'] = data['brand']
# 
data['firm_ids'] = 0
# Para Tylenol (valor 1)
data.loc[ (data.product_ids >=1) & (data.product_ids<=3), 'firm_ids' ] = 1
# Para Advil (valor 2)
data.loc[ (data.product_ids >=4) & (data.product_ids<=6), 'firm_ids' ] = 2
# Para Bayer (valor 3)
data.loc[ (data.product_ids >=7) & (data.product_ids<=9), 'firm_ids' ] = 3
# Para Generico 10 
data.loc[ (data.product_ids ==10), 'firm_ids' ] = 4
# Para Generico 11
data.loc[ (data.product_ids ==11), 'firm_ids' ] = 5
# Crear shares
data['shares'] = data['sales'] / data['count']

demo['market_ids'] = demo['store']*100 + demo['week']
# Crear 20 filas duplicando market_ids
# Tomar cada fila, transponer y 2 juntar














