import pandas
import matplotlib.pyplot als plt

all_data = pandas.read_csv(...)


# Extract many things from the big data table, make plots.

all_data.plot(x='mmgbsa_freemdlast250frames_deltag', y='mmpbsa_freemdlast250frames_deltag', marker='o', linestyle='None')
