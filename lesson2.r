#!/usr/bin/env Rscript

#I'm such a hadley fanboy
#source('http://bioconductor.org/biocLite.R')
library(rgl)
library(RColorBrewer)
library(preprocessCore)
library(ggplot2)
library(dplyr)
library(tidyr)
#library(ggdendro)
library(gridExtra)
library(igraph)
theme_set(theme_bw())

data = read.csv("singaporeFlights.csv")

data$mth = substr(data$X, start = 6, stop=7)
data$yr= substr(data$X, start = 1, stop=4)

df = data %>% 
select(-c(TOTAL.REGIONS, X))
rownames(df)=data$X
df$date = data$X


df.long = df %>% 
gather(area, absCount, -c(date, mth,yr))

qplot(yr, log10(absCount), data = df.long, geom="boxplot")

qplot(x=date, y=absCount,data = df.long)+facet_wrap(~area)
#qplot(x=date, y=absCount,data = df.long)+facet_wrap(~area, scales='free')

byDate = df.long %>% 
group_by(mth,yr,area) %>%
summarise(total = sum(absCount))

qplot(area, total, data = byDate,geom="bar",stat="identity",fill=mth,position="dodge")+facet_wrap(~yr)+theme(axis.text.x=element_text(angle=90))
##################################################
#Looking for Patterns Normalisation
##################################################
tonormalise = df.long %>% select(-date) %>% spread(yr, absCount, fill=0)
normalised = setNames(as.data.frame(normalize.quantiles(as.matrix(tonormalise[,-c(1,2)]))), colnames(tonormalise)[-c(1,2)]) 
newDF.long = cbind(tonormalise[,c(1,2)], normalised) %>% gather(year, count, -c(mth, area))
newDF.long$date = paste0(newDF.long$year, newDF.long$mth)

qplot(year, log10(count), data = newDF.long, geom="boxplot")
qplot(x=date, y=count,data = newDF.long)+facet_wrap(~area)

byDate.norm= newDF.long %>% 
select(-date) %>%
group_by(mth,year,area) %>%
summarise(total = sum(count))

qplot(area, total, data = byDate.norm,geom="bar",stat="identity",fill=mth,position="dodge")+
facet_wrap(~year)+theme(axis.text.x=element_text(angle=90))
newDF.wide = newDF.long %>% spread(area, count)

##################################################
#Hierarchical Clustering
##################################################

hc.regions = hclust(dist(scale(t(df %>% select(SOUTH.EAST.ASIA:OTHER.REGIONS)))))

#ggdendrogram(hc.regions)
plot(hc.regions)

##################################################
#K-means
##################################################
#Excluded 
# | Column | Description | 
# |--------|-------------|
# | X      | Date        |
#| Total regions | wouldnt want to double count| 


#choosing the # of K's
wss = rep(0, 10)
for (i in 2:12) wss[i] = sum(kmeans(t(newDF.wide[,-c(1,2,3)]), centers=i, nstart=100, iter.max=1000)$withinss)



#Method1: Eyeballing
qplot(x=1:11, y=wss[-1], geom=c("point", "line"))+ylab("Within groups sum of squares")+xlab("Number of centers")

#Method2: Pseudo F-test
#Not today

k = kmeans(x=t(df[,1:19]), center= 5, nstart = 25, iter.max=1000)
kmeans.df = data.frame(k$cluster)
kmeans.df$name = rownames(kmeans.df)
kmeans.df$id = 1:nrow(kmeans.df)
kmeans.df$col = kmeans.df$k.cluster
kmeans.df$col  = factor(kmeans.df$col, labels= brewer.pal(n=5, name='Set3'))
adjMatrix = matrix(rep(0,nrow(kmeans.df)*nrow(kmeans.df)), ncol=nrow(kmeans.df),nrow=nrow(kmeans.df))


sapply(unique(kmeans.df$name),function(namae){
row=subset(kmeans.df, name == namae)$id
col=subset(kmeans.df, k.cluster == subset(kmeans.df, name == namae)$k.cluster)$id
adjMatrix[row,col]<<-1
})


plot(simplify(
graph.adjacency(adjmatrix=adjMatrix)),
     vertex.label=kmeans.df$name, vertex.color=kmeans.df$col)
#PCA

svdObj = svd(scale(df %>% select(SOUTH.EAST.ASIA:OTHER.REGIONS)))
grid.arrange(qplot(1:length(svdObj$u[,1]), svdObj$u[,1], geom=c("point","line")),
qplot(1:length(svdObj$u[,2]), svdObj$u[,2], geom=c("point","line")),
qplot(1:length(svdObj$u[,3]), svdObj$u[,3], geom=c("point","line")))

clus = kmeans(svdObj$v[,1:3], centers=3, nstart=25, iter.max=1000)$cluster

plot3d(svdObj$v[,1], svdObj$v[,2], svdObj$v[,3], size=10, col=clus)
text3d(svdObj$v[,1:3], text=colnames(df)[1:19], cex = 1,col=clus)
rownames(svdObj$v) <- colnames(df)[1:19]
pca.hc = hclust(dist(svdObj$v[,1:3]))
plot(pca.hc)
