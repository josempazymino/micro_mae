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

############################
############################

# Crea market_ids
data['market_ids'] = data['store']*100 + data['week']
demo['market_ids'] = demo['store']*100 + demo['week']
ivs['market_ids']  = ivs['store']*100 + ivs['week']

# Reordena demo
demo1  = demo.drop(['market_ids', 'store', 'week'], axis=1)
demo1t = demo1.T

demo2 = pd.DataFrame(np.repeat(demo[['store', 'week', 'market_ids']].values, 20, axis = 0))
demo2.columns = ['store', 'week', 'market_ids']
market_list = demo2.market_ids.unique()

cc = []
for index, rr in demo1.iterrows():
	ss = pd.DataFrame({'aa':rr.T}).reset_index()
	cc.append(ss)
	#demo2.loc[demo2.market_ids == ic, 'income'] = bb
cc = 	pd.concat(cc)		
demo2['income'] = cc['aa'].values

vv = vv.iloc[0:,0:20]
vvtotal = demo2[['store', 'week', 'market_ids']]
cc = []
for index, rr in vv.iterrows():
	zz = pd.DataFrame({'aa':rr.T}).reset_index()
	cc.append(zz)
	#demo2.loc[demo2.market_ids == ic, 'income'] = bb
cc = 	pd.concat(cc)		
vvtotal['node1'] = cc['aa'].values

############################
############################

# Nos quedamos con algunos mercado
datatotal = data[data.week <= 10]
demototal = demo2[demo2.week <= 10]
ivtotal   = ivs[ivs.week <= 10]
vvtotal   = vvtotal[vvtotal.week <= 10]

############################
############################

# Debemos adaptar de acuerdo a programa

# datatotal
datatotal.rename(columns={'brand':'brand_ids', 'price':'prices'}, inplace=True)
datatotal['product_ids'] = datatotal['brand_ids']
datatotal['firm_ids'] = 0
datatotal.loc[ (datatotal.brand_ids>=4) & (datatotal.brand_ids<=6), 'firm_ids'  ] = 1
datatotal.loc[ (datatotal.brand_ids>=7) & (datatotal.brand_ids<=9), 'firm_ids'  ] = 2
datatotal.loc[ (datatotal.brand_ids>=10), 'firm_ids'  ] = 3
datatotal['shares'] = datatotal['sales'] / datatotal['count']

############################
############################



