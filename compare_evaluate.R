###GRACE_tutorial_drosophila_old.R完整的评估过程

lst.validation <- list(lst.data$mat.chip, lst.data$mat.string)
names(lst.validation) <- c("n.gs.grn.Chip","n.coreg.String")
code.validation <- c("regulatory_evidence", "cofunctional_evidence")


#验证数据集
print("Computing averaged bootstrap error validation - using same size network")
### compute the bootstrap averaged errors 
validationSet = c("Gene regulatory links (Non-Specific-Chip)", 
                  "Gene regulatory links (ChIP-seq-network)", 
                  "Co-functional pairs (MouseNetv2_GS_symbol)",
                  "Protein-protein interaction (STRING)") 

v.sets_map <-  c('n.gs.grn','n.gs.grn.Chip','n.coreg.bp_tg_pairs','n.coreg.String')#df.rate_density的(2,7,3,8)列
names(v.sets_map) <- validationSet

methods_name<- c("RF_row", "xgboost",'SCODE')
l.foldchanges <- vector(mode = "list", length = length(methods_name))
for(m in 1:length(methods_name)){
  l.foldchanges[[m]] <- vector(mode = "list", length = 2)
  names(l.foldchanges[[m]]) <- c("GRACE", "Original")
  for(j in 1:2){
    l.foldchanges[[m]][[j]] <- vector(mode = "list", length = length(validationSet))
    for(s in 1:length(validationSet)){
      l.foldchanges[[m]][[j]][[s]] <- numeric(n.models)
    }
  }
}
#初始化的结构相同
l.foldchanges_comparative <-l.pvalues_comparative <-  l.pvalues <-l.foldchanges
names(l.foldchanges) <- methods_name
names(l.pvalues) <- methods_name
names(l.pvalues_comparative) <- methods_name
names(l.foldchanges_comparative) <- methods_name


v.background = df.rate_density[nrow(df.rate_density),]
n.pred.background <- df.rate_density$n.pred[nrow(df.rate_density)]
n.coreg.background <- df.rate_density$n.coreg.tg_pairs[nrow(df.rate_density)]
v.backgroundSet <- as.numeric(df.rate_density[nrow(df.rate_density),v.sets_map]) # needs to be adjusted
names(v.backgroundSet) <- validationSet

# generate training and test bootstrap prediction errors

#读取各个对比方法推断的GRN
# GENIE3, GGM, CLR, BC3NET, wGLASSO, iRafNet
l.methods <- vector(mode = "list", length = length(methods_name))
names(l.methods) <- methods_name
l.methods[[1]] <- readRDS(paste(rdir,'m.grn_rf.rds',sep = '/'))[v.tfs,v.tgs]
l.methods[[2]] <- readRDS(paste(rdir,'m.grn_xgboost.rds',sep = '/'))[v.tfs,v.tgs]

SCODE<- read.table(paste('Result',dset,'SCODE','A.txt',sep = '/'), header=TRUE, sep="\t")
SCODE <- as.matrix(SCODE)
SCODE <- abs(mapping_intervals(SCODE, min(SCODE), max(SCODE), -1, 1)) #标准化
l.methods[[3]] <- SCODE
# l.methods[[3]] <- l.methods[[4]] <- l.methods[[1]]
# l.methods[[2]] <- readRDS("drosophila_datasets/mat.grn.clr_drosophila.rds")[v.tfs,v.tgs]
# #l.methods[[3]] <- readRDS("drosophila_datasets/mat.grn.aracne_drosophila.rds")[v.tfs,v.tgs]
# # l.methods[[4]] <- readRDS("bc3net_drosophila.rds")[v.tfs,v.tgs]
# l.methods[[3]] <- readRDS("drosophila_datasets/ggm_drosophila.rds")[v.tfs,v.tgs]
# #l.methods[[5]] <- readRDS("glasso_drosophila.rds")
# l.methods[[4]] <- abs(readRDS("drosophila_datasets/wGlasso_drosophila.rds")[v.tfs,v.tgs])

#rownames(l.methods[[5]]$wi) <- colnames(l.methods[[5]]$wi) <- v.gns
#saveRDS(l.methods[[5]]$wi[v.tfs,v.tgs], "drosophila_datasets/wGlasso_drosophila.rds")
# l.methods[[5]]

# readRDS("iRafNet_drosophila")

#背景
n.links_background <- length(v.tfs) * length(v.tgs)
n.co_pairs <- length(v.tgs) * length(v.tgs)

n.gs_background <- sum(mat.regulatory_evidence[intersect(rownames(mat.regulatory_evidence), v.tfs), intersect(colnames(mat.regulatory_evidence), v.tgs)]) # 386 
n.chip_background <- sum(lst.validation$n.gs.grn.Chip[intersect(rownames(lst.validation$n.gs.grn.Chip), v.tfs), intersect(colnames(lst.validation$n.gs.grn.Chip), v.tgs)])

v.gs.grn <- c(n.gs_background, n.chip_background)
v.gs.copairs <- c(sum(mat.cofunctional_evidence[v.tgs,v.tgs]), sum(lst.validation$n.coreg.String[v.tgs,v.tgs]))

####
# t区分训练集和测试集，i遍历n.models个模型，m遍历各个对比方法，j区分GRACE和原始方法，s遍历各个验证集（benchmark+validation）
for(t in 1:2){
  
  if(t == 1){ #b.validation=FALSE训练集
    b.validation <- FALSE
  }else{
    b.validation <- TRUE
  }
  
  for(i in 1:n.models){
    
    cat("Processing... ", round(i/n.models * 100, digits = 2) , "%", "\r"); flush.console() 
    
    # use different seeds per run (simulated annealing)
    v.seed = 1234 + 158 * i
    set.seed(v.seed)
    
    #### Bootstrapping (based on regulators based meta module sampling (0.632))
    tfs.mrf <- unique(lst.grace_support$df.grn$TF) 
    tgs.mrf <- unique(lst.grace_support$df.grn$TG)
    
    lst.bootstrap_sample <- generate_bootstrapping_sample(lst.grace_support=lst.grace_support,lst.modules=lst.modules, truereg=as.matrix(truereg), mat.cofunctional_evidence=mat.cofunctional_evidence, n.sample_size = n.sample_size, b.validation = b.validation)
    lst.grace_support.bootstrap_sample <- lst.bootstrap_sample$lst.grace_support.bootstrap_sample
    lst.modules.bootstrap_sample <- lst.bootstrap_sample$lst.modules.bootstrap_sample
    
    lst.benchmarks <- list(lst.bootstrap_sample$lst.benchmark.bootstrap_sample$mat.GS.bootstrap_sample, lst.bootstrap_sample$lst.benchmark.bootstrap_sample$mat.cofunctional_evidence.bootstrap_sample)    #list(mat.GS.train, mat.BP.coreg.train)
    names(lst.benchmarks) <- c("mat.regulatory_evidence", "mat.cofunctional_evidence")
    
    lst.validation <- list(lst.data$mat.chip,  lst.data$mat.string)
    names(lst.validation) <- c("n.gs.grn.Chip","n.coreg.String")
    code.validation <- c("regulatory_evidence", "cofunctional_evidence")
    
    ####
    
    alpha  <- lst.grace_models[[i]]$weights[1]
    gamma  <- lst.grace_models[[i]]$weights[2]
    lambda <- lst.grace_models[[i]]$weights[3]
    lst.mat.p.crf <- reevaluate_links_with_MarkovRandomFields(lst.grace_support=lst.grace_support, lst.modules=lst.modules, 
                                                              v.alpha = alpha, v.gamma=gamma, v.lambda=lambda, b.prim=TRUE) 
    mat.p.crf <- lst.mat.p.crf$mat.p.crf
    
    ### 
    
    l.eval <- vector(mode = "list", length = 2)
    #l.eval[[1]]表示GRACE，l.eval[[2]]表示对比方法,
    # 因此l.foldchanges和l.pvalues的[[m]][[1]]都是相等的，且表示GRACE，[[m]][[2]]即original表示对比方法的结果
    l.eval[[1]] <- compute_grace_complete_assessment(mat.grace=mat.p.crf, 
                                                     lst.benchmarks=lst.benchmarks,
                                                     lst.validation=lst.validation,
                                                     code.validation = code.validation)
    
    
    n.links <- sum(mat.p.crf)
    
    #n.links_background <- length(v.tfs) * length(v.tgs)
    #n.gs_background <- sum(mat.regulatory_evidence)
    #n.co_pairs <- length(v.tgs) * length(v.tgs)
    # all methods as comparison models here #
    for(m in 1:length(l.methods)){
      
      mat.gene_regulatory_network <- as.matrix(l.methods[[m]])
      
      mat.grn.comparison <- mat.gene_regulatory_network[v.tfs,v.tgs]
      # mat.grn.comparison <- mat.grn.comparison[rownames(lst.benchmarks$mat.regulatory_evidence),]
      
      df.grn.comparison <- as.data.frame(as.table(mat.grn.comparison), stringsAsFactors = FALSE) 
      names(df.grn.comparison)[1:3] <- c("TF","TG","v.grn")
      
      df.grn.comparison <- subset(df.grn.comparison, df.grn.comparison$v.grn > 0)
      
      df.grn.comparison <- df.grn.comparison[order(-df.grn.comparison$v.grn),] 
      df.grn.comparison <- df.grn.comparison[1:n.links,]#取相同数量的top link
      
      mat.grn.comparison <- acast(df.grn.comparison, TF~TG, value.var="v.grn")
      mat.grn.comparison[is.na(mat.grn.comparison)] <- 0; 
      mat.grn.comparison[mat.grn.comparison > 0] <- 1
      
      l.eval[[2]] <- compute_grace_complete_assessment(mat.grace=mat.grn.comparison, 
                                                       lst.benchmarks=lst.benchmarks,
                                                       lst.validation=lst.validation,
                                                       code.validation = code.validation)
      
      for(j in 1:2){
        
        # print(j)
        for(s in 1:length(v.sets_map)){
          
          hitInSample <- l.eval[[j]][[v.sets_map[s]]]
          
          if(s <= 2){
            hitInPop <- v.gs.grn[s]
            sampleSize <- n.links
            failInPop <- (n.links_background - hitInPop)
            foldchange <- (hitInSample/sampleSize)/(hitInPop/n.links_background)
          }else{
            hitInPop <- v.gs.copairs[s - 2]
            sampleSize <- l.eval[[j]]$n.coreg.tg_pairs
            failInPop <- (n.co_pairs - hitInPop)
            foldchange <- (hitInSample/sampleSize)/(hitInPop/n.co_pairs)
          }
          
          #print(foldchange)
          
          p.val <- phyper(hitInSample-1, hitInPop, failInPop, sampleSize, lower.tail= FALSE)
          #l.foldchanges表示FC=GRACE或对比方法/大背景
          l.foldchanges[[m]][[j]][[s]][[i]] <- foldchange
          l.pvalues[[m]][[j]][[s]][[i]] <- p.val
          
        }
        #print("")
      }
      
      ### comparative enrichment 
      
      for(s in 1:length(v.sets_map)){
        
        hitInSample <- l.eval[[1]][[v.sets_map[s]]]
        hitInPop <- l.eval[[2]][[v.sets_map[s]]]
        
        if(s <= 2){
          sampleSize <- n.links
          failInPop <- (n.links - hitInPop)
          foldchange <- (hitInSample/n.links)/(hitInPop/n.links)
        }else{
          sampleSize <- l.eval[[1]]$n.coreg.tg_pairs
          failInPop <- (l.eval[[2]]$n.coreg.tg_pairs - hitInPop)
          foldchange <- (hitInSample/sampleSize)/(hitInPop/l.eval[[2]]$n.coreg.tg_pairs)
        }
        
        tab <- matrix(c(hitInSample, hitInPop, sampleSize - hitInSample, failInPop), nrow = 2)
        p.val <- fisher.test(tab)$p.value
        
        # l.foldchanges_comparative表示FC=GRACE/对比方法
        l.foldchanges_comparative[[m]][[j]][[s]][[i]] <- foldchange
        l.pvalues_comparative[[m]][[j]][[s]][[i]] <- p.val
        
      }
    }
  }
  
  if(t == 1){
    l.foldchanges.training <- l.foldchanges
    l.pvalues.training <- l.pvalues
    l.foldchanges_comparative.training <- l.foldchanges_comparative
    l.pvalues_comparative.training <- l.pvalues_comparative
  }else{
    l.foldchanges.testing <- l.foldchanges
    l.pvalues.testing <- l.pvalues
    l.foldchanges_comparative.testing <- l.foldchanges_comparative
    l.pvalues_comparative.testing <- l.pvalues_comparative
  }
  
  # compute the actual values instead of fold changes
  # individual comparative enrichment tests
  
}
### 

#GRACE方法在4个评估集下的结果（m可以为任何，因为在几种对比方法下的GRACE都是相同的）
print(lapply(l.foldchanges.testing[[m]][[1]], mean))
print(lapply(l.pvalues.testing[[m]][[1]], mean))
# print(lapply(l.foldchanges.testing[[m]][[2]], mean))
print(lapply(l.foldchanges.training[[m]][[1]], mean))

#对比方法在4个评估集下的结果
for(m in 1:length(methods_name)){
  
  print(names(l.methods)[m])
  
  #l.foldchanges.training
  
  
  #l.foldchanges_comparative.testing[[m]][[2]] <- lapply(l.foldchanges_comparative.testing[[m]][[2]], function(m) m[m != "Inf"])
  
  #print(lapply(l.foldchanges_comparative.testing[[m]][[2]], mean))
  # print(lapply(l.pvalues_comparative.testing[[m]][[2]], mean))
  
  # print(lapply(l.pvalues_comparative.testing[[m]][[2]], mean))
  
  # print(lapply(l.foldchanges.training[[m]][[2]], mean))
  
  # print(lapply(l.foldchanges.testing[[m]][[2]], mean))
  print(lapply(l.pvalues.testing[[m]][[2]], mean))
  
  # lapply(l.foldchanges.training[[1]], mean)
  # lapply(l.foldchanges.training[[2]], mean)
}

#GRACE比上对比方法在4个评估集下的结果
for(m in 1:length(methods_name)){
  
  print(names(l.methods)[m])
  
  print(lapply(l.foldchanges_comparative.testing[[m]][[2]], mean))
  print('p-values')
  print(lapply(l.pvalues_comparative.testing[[m]][[2]], mean))
  
}

saveRDS(l.foldchanges,file =paste(rdir,'l.foldchanges.rds',sep = '/'))
saveRDS(l.foldchanges.training,file =paste(rdir,'l.foldchanges.training.rds',sep = '/'))
saveRDS(l.foldchanges.testing,file =paste(rdir,'l.foldchanges.testing.rds',sep = '/'))
saveRDS(l.foldchanges_comparative.training,file =paste(rdir,'l.foldchanges_comparative.training.rds',sep = '/'))
saveRDS(l.foldchanges_comparative.testing,file =paste(rdir,'l.foldchanges_comparative.testing.rds',sep = '/'))

saveRDS(l.pvalues,file =paste(rdir,'l.pvalues.rds',sep = '/'))
saveRDS(l.pvalues.training,file =paste(rdir,'l.pvalues.training.rds',sep = '/'))
saveRDS(l.pvalues.testing,file =paste(rdir,'l.pvalues.testing.rds',sep = '/'))
saveRDS(l.pvalues_comparative.training,file =paste(rdir,'l.pvalues_comparative.training.rds',sep = '/'))
saveRDS(l.pvalues_comparative.testing,file =paste(rdir,'l.pvalues_comparative.testing.rds',sep = '/'))



# for supplement details and barplot
0.632 * unlist(lapply(l.foldchanges.testing[[1]], mean)) + 0.368 * unlist(lapply(l.foldchanges.training[[1]], mean)) # GRACE
0.632 * unlist(lapply(l.foldchanges.testing[[2]], mean)) + 0.368 * unlist(lapply(l.foldchanges.training[[2]], mean)) # initial network at similar size cutoff comparison (avoid naming GENIE3)

0.5 * unlist(lapply(l.pvalues.testing[[1]], mean)) + 0.5 * unlist(lapply(l.pvalues.training[[1]], mean))
0.5 * unlist(lapply(l.pvalues.testing[[2]], mean)) + 0.5 * unlist(lapply(l.pvalues.training[[2]], mean))

# GRACE vs ... 
# main barplots 



#

print("build final ensemble model")
# model averaging - ensemble model building
alpha  <- lst.grace_models[[1]]$weights[1]
gamma  <- lst.grace_models[[1]]$weights[2]
lambda <- lst.grace_models[[1]]$weights[3]
lst.mat.p.crf <- reevaluate_links_with_MarkovRandomFields(lst.grace_support=lst.grace_support, lst.modules=lst.modules, 
                                                          v.alpha = alpha, v.gamma=gamma, v.lambda=lambda, b.prim=TRUE) 
mat.p.crf <- lst.mat.p.crf$mat.p.crf
n.models <- length(lst.grace_models)

for(j in 2:n.models){
  
  cat("Processing... ", round(j/n.models * 100, digits = 2) , "%", "\r"); flush.console()  
  alpha  <- lst.grace_models[[j]]$weights[1]
  gamma  <- lst.grace_models[[j]]$weights[2]
  lambda <- lst.grace_models[[j]]$weights[3]
  lst.mat.p.crf <- reevaluate_links_with_MarkovRandomFields(lst.grace_support=lst.grace_support, lst.modules=lst.modules, 
                                                            v.alpha = alpha, v.gamma=gamma, v.lambda=lambda, b.prim=TRUE) 
  mat.p.crf <- mat.p.crf + lst.mat.p.crf$mat.p.crf
}

mat.p.grace_ensemble <- mat.p.crf
mat.p.grace_ensemble <- mat.p.grace_ensemble/n.models

# define probabilistic cutoff {0.5 - 1}
# th.p.cutoff <- as.numeric(quantile(mat.p.grace_ensemble[mat.p.grace_ensemble>0], 0.5))
th.p.cutoff <- 0.5 # epsion parameter (defaul = 0.5, models = 100, simulated annealing runs)

if(th.p.cutoff == 0.5){
  mat.p.grace_ensemble[mat.p.grace_ensemble <= th.p.cutoff] <- 0
  mat.p.grace_ensemble[mat.p.grace_ensemble > th.p.cutoff] <- 1
}else{
  mat.p.grace_ensemble[mat.p.grace_ensemble < th.p.cutoff] <- 0
  mat.p.grace_ensemble[mat.p.grace_ensemble >= th.p.cutoff] <- 1
}



# df.grace.ensemble <- as.data.frame(as.table(mat.p.grace_ensemble), stringsAsFactors = FALSE) 
# names(df.grace.ensemble)[1:3] <- c("TF","TG","value")
# df.grace.ensemble <- subset(df.grace.ensemble, df.grace.ensemble$value > 0)
# df.grace.ensemble <- df.grace.ensemble[order(-df.grace.ensemble$value),] 
# 
# write.csv(df.grace.ensemble[,1:2], "prediction_drosophila_graceEnsemble.csv", row.names = FALSE)
# 

#集成n.methods个模型的结果，用独立的验证集进行评估

# evaluate the ensemble model
l.eval <- vector(mode = "list", length = 2)

l.eval[[1]] <- compute_grace_complete_assessment(mat.grace=mat.p.grace_ensemble, 
                                                 lst.benchmarks=lst.benchmarks,
                                                 lst.validation=lst.validation,
                                                 code.validation = code.validation)


n.links <- sum(mat.p.grace_ensemble)

for(m in 1:length(l.methods)){
  
  mat.gene_regulatory_network <- as.matrix(l.methods[[m]])
  
  mat.grn.comparison <- mat.gene_regulatory_network[v.tfs,v.tgs]
  # mat.grn.comparison <- mat.grn.comparison[rownames(lst.validation$mat.regulatory_evidence),]
  
  df.grn.comparison <- as.data.frame(as.table(mat.grn.comparison), stringsAsFactors = FALSE) 
  names(df.grn.comparison)[1:3] <- c("TF","TG","v.grn")
  df.grn.comparison <- subset(df.grn.comparison, df.grn.comparison$v.grn > 0)
  df.grn.comparison <- df.grn.comparison[order(-df.grn.comparison$v.grn),] 
  df.grn.comparison <- df.grn.comparison[1:n.links,]
  
  mat.grn.comparison <- acast(df.grn.comparison, TF~TG, value.var="v.grn")
  mat.grn.comparison[is.na(mat.grn.comparison)] <- 0; 
  mat.grn.comparison[mat.grn.comparison > 0] <- 1
  
  l.eval[[2]] <- compute_grace_complete_assessment(mat.grace=mat.grn.comparison, 
                                                   lst.benchmarks=lst.benchmarks,
                                                   lst.validation=lst.validation,
                                                   code.validation = code.validation)
  
  
  for(j in 1:2){
    
    for(s in 1:length(v.sets_map)){
      
      hitInSample <- l.eval[[j]][[v.sets_map[s]]]
      
      if(s <= 2){
        hitInPop <- v.gs.grn[s]
        sampleSize <- n.links
        failInPop <- (n.links_background - hitInPop)
        foldchange <- (hitInSample/sampleSize)/(hitInPop/n.links_background)
      }else{
        hitInPop <- v.gs.copairs[s - 2]
        sampleSize <- l.eval[[j]]$n.coreg.tg_pairs
        failInPop <- (n.co_pairs - hitInPop)
        foldchange <- (hitInSample/sampleSize)/(hitInPop/n.co_pairs)
      }
      
      #print(foldchange)
      
      p.val <- phyper(hitInSample-1, hitInPop, failInPop, sampleSize, lower.tail= FALSE)
      
      l.foldchanges[[m]][[j]][[s]][[i]] <- foldchange
      l.pvalues[[m]][[j]][[s]][[i]] <- p.val
      
    }
  }
  
  for(s in 1:length(v.sets_map)){
    
    hitInSample <- l.eval[[1]][[v.sets_map[s]]]
    hitInPop <- l.eval[[2]][[v.sets_map[s]]]
    
    if(s <= 2){
      sampleSize <- n.links
      failInPop <- (n.links - hitInPop)
      foldchange <- (hitInSample/n.links)/(hitInPop/n.links)
    }else{
      sampleSize <- l.eval[[1]]$n.coreg.tg_pairs
      failInPop <- (l.eval[[2]]$n.coreg.tg_pairs - hitInPop)
      foldchange <- (hitInSample/sampleSize)/(hitInPop/l.eval[[2]]$n.coreg.tg_pairs)
    }
    
    tab <- matrix(c(hitInSample, hitInPop, sampleSize - hitInSample, failInPop), nrow = 2)
    p.val <- fisher.test(tab)$p.value
    
    l.foldchanges_comparative[[m]][[j]][[s]][[i]] <- foldchange
    l.pvalues_comparative[[m]][[j]][[s]][[i]] <- p.val
    
  }
  
}


l.foldchanges.testing <- l.foldchanges
l.pvalues.testing <- l.pvalues
l.foldchanges_comparative.testing <- l.foldchanges_comparative
l.pvalues_comparative.testing <- l.pvalues_comparative

#集成所有模型后GRACE比上对比方法在4个评估集下的结果
for(m in 1:length(methods_name)){
  
  print(names(l.methods)[m])
  
  print(lapply(l.foldchanges_comparative[[m]][[2]], mean))
  print('p-values')
  print(lapply(l.pvalues_comparative[[m]][[2]], mean))
  
}






# 
# lst.eval <-  compute_grace_ensemble_model_assessment(mat.p.grace_ensemble=mat.p.grace_ensemble,
#                                                      lst.benchmarks=lst.benchmarks,
#                                                      mat.AtRegNet=mat.AtRegNet,
#                                                      mat.MR.subacon.tgs=mat.MR.subacon.tgs,
#                                                      mat.aracyc.tgs=mat.aracyc.tgs,
#                                                      b.jaccard = TRUE,
#                                                      th.min.coreg.tfs = 1,
#                                                      beta = beta)

print(unlist(lst.eval))

# that is the comparison model - equal size, f score are not really comparable
lst.mat.grn.cns.comparison <- vector(mode = "list", length = 2)

print("characteristics of equal size comparison network")
idx.equal_size <- max(which(df.rate_density$n.pred <= lst.eval$n.pred))
print(df.rate_density[idx.equal_size,])

# automatic enrichment analysis

th.grn.comparison <- df.rate_density$th.grn[idx.equal_size]
lst.mat.grn.cns.comparison[[1]] <- mat.gene_regulatory_network
lst.mat.grn.cns.comparison[[1]][lst.mat.grn.cns.comparison[[1]] < th.grn.comparison] <- 0
lst.mat.grn.cns.comparison[[1]][lst.mat.grn.cns.comparison[[1]] >= th.grn.comparison] <- 1

mat.grn.cns.comparison=lst.mat.grn.cns.comparison[[1]]


# general overlap and network properties
compute_NetworkOverlap(mat.p.grace_ensemble, mat.grn.cns.comparison, trace = TRUE, test = "hyper")
print(paste("GRACE: # regulators:", length(which(rowSums(mat.p.grace_ensemble) > 0)), " # targets:", length(which(colSums(mat.p.grace_ensemble) > 0)) ))
print(paste("COMPARISON: # regulators:", length(which(rowSums(mat.grn.cns.comparison) > 0)), " # targets:", length(which(colSums(mat.grn.cns.comparison) > 0)) ))

# coregulation enrichment
hitInSample <- lst.eval$n.coreg.tg_pairs
sampleSize <-  length(which(colSums(mat.p.grace_ensemble) > 0)) *  length(which(colSums(mat.p.grace_ensemble) > 0))
hitInPop <- df.rate_density$n.coreg.tg_pairs[idx.equal_size]
popSize <- length(which(colSums(mat.grn.cns.comparison) > 0)) * length(which(colSums(mat.grn.cns.comparison) > 0))
(hitInSample/sampleSize)/(hitInPop/popSize)

tab <- matrix(c(hitInSample, hitInPop, sampleSize - hitInSample, popSize - hitInPop), nrow = 2)
fisher.test(tab)$p.value


###

print("characteristics of best fscore comparison network")
idx.best_fscore <- max(which(df.rate_density$fscore_beta_01 == max(df.rate_density$fscore_beta_01)))
print(df.rate_density[idx.best_fscore,])

th.grn.comparison <- df.rate_density$th.grn[idx.best_fscore]
lst.mat.grn.cns.comparison[[2]] <- mat.gene_regulatory_network
lst.mat.grn.cns.comparison[[2]][lst.mat.grn.cns.comparison[[2]] < th.grn.comparison] <- 0
lst.mat.grn.cns.comparison[[2]][lst.mat.grn.cns.comparison[[2]] >= th.grn.comparison] <- 1

###


lst.eval_grace=lst.eval
v.comparison_best_fscore = df.rate_density[idx.best_fscore,]
v.comparison_equal_size = df.rate_density[idx.equal_size,]
v.background = df.rate_density[nrow(df.rate_density),]

plot_GRACE_validation(lst.eval_grace=lst.eval_grace, v.comparison_best_fscore = v.comparison_best_fscore, v.comparison_equal_size = v.comparison_equal_size, v.background = v.background)

