#! python


def build(ctx):
	
    # Class 1: OLS	
	ctx(
	features ='run_r_script',
	source   ='exercise_1_clean.r',
	target   =[
	ctx.path_to(ctx, 'OUT_ANALYSIS_BEEF', 'monthly_data_short'),
	],
	deps     =[
	ctx.path_to(ctx, 'IN_DATA_BEEF', 'monthly_data.csv')
	],
	name='class_1')


