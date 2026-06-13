# Importing the libraries needed 
library(gam)
library(xgboost)
library(tidyverse)
library(glmnet)
library(caret)
library(ggplot2)
library(ggrepel)
library(ggpubr)
library(dplyr)
library(plyr)
library(maps)
library(cowplot)
library(MASS)
library(rpart)
library(rpart.plot)
library(gglasso)
library(factoextra)
library(cluster)


# Importing the dataset
Data = read.csv("BrazHousesRent.csv", sep = ",", dec = ".", header = T, colClasses = "character")


# 1 - Overview of the dataset

# Remiving duplicate rows
Data <- unique(Data)

# Counting the occurences
count_zero <- sum(Data$floor == "-")
print(paste("The number of observations with floor '-' is:", count_zero))

# Counting observations with floor '-' and hoa 0, we also show their proportion
floor_abs <- subset(Data, floor == "-", select = hoa..R..)
floor_abs[,1] = as.numeric(floor_abs[,1])
count_zero <- sum(floor_abs[, 1] == 0)
print(paste("Number of observations with floor '-' and HOA = 0:", count_zero))
print(paste("Proportion of observations with floor '-' and HOA = 0:", count_zero/length(floor_abs[, 1])))

# Replace '-' by 0 in the floor column
Data[Data == "-"] <- 0

# Set the variables to either numeric or factors
categ <- c("city","animal","furniture")
cols <- colnames(Data)
for(i in 1:ncol(Data)){
  if (cols[i] %in% categ){
    Data[,i] = as.factor(Data[,i])
  }else{
    Data[,i] = as.numeric(Data[,i])
  }
}


# Looking at the response variable

# Function that computes the average rent amount for a given city
average_rent_price <- function(City) {
  city_rent_amounts <- subset(Data, city == City, select = rent.amount..R..)
  average_rent <- mean(city_rent_amounts$rent.amount..R..)
  return(average_rent)
}

# Geospatial plot
city_data <- data.frame(
  City = c("Belo Horizonte", "Campinas", "Porto Alegre", "Rio de Janeiro", "Sao Paulo"),
  Latitude = c(-19.9167, -22.9071, -30.0346, -22.9068, -23.5505),
  Longitude = c(-43.9345, -47.0632, -51.2177, -43.1729, -46.6333),
  Average_Rent = sapply(c("Belo Horizonte", "Campinas", "Porto Alegre", "Rio de Janeiro", "São Paulo"), 
                        function(x) average_rent_price(x))
)

city_data$Alpha <- (city_data$Average_Rent -
                      min(city_data$Average_Rent)) / (max(city_data$Average_Rent) 
                                                      - min(city_data$Average_Rent))

# Plot the geospatial data for Brazil only
map_brazil <- map_data("world", region = "Brazil")

# Create the plot
ggplot() +
  geom_polygon(data = map_brazil, aes(x = long, y = lat, group = group), fill = "lightgray", color = "white") +
  geom_label_repel(data = city_data, aes(x = Longitude, y = Latitude, label = City), color = "black", size = 3,
                   box.padding = 0.5, point.padding = 0.2, force = 1, segment.color = "transparent") +
  geom_point(data = city_data, aes(x = Longitude, y = Latitude, color = Average_Rent), alpha = 0.8, size = 5) +
  labs(title = "Average Rent in Different Cities in Brazil",
       x = "Longitude",
       y = "Latitude") +
  scale_color_gradient(low = "blue", high = "red") +
  theme_minimal()

# Correlation between fire insurance and rent amount
cor(Data$fire.insurance..R..,Data$rent.amount..R..)


# 3 - Lower Dimensional Models

# Log linear regression model
fit1 <- lm(log(rent.amount..R..) ~ area,data = Data)
summary(fit1)$coefficients

# Decision tree
dtree <- rpart(rent.amount..R.. ~ rooms + furniture + bathroom, data = Data, method = "anova")
rpart.plot(dtree)


# 4 - Getting the data ready

# Continuous variables
cont <- c("area","fire.insurance..R..","property.tax..R..","hoa..R..", "floor")

#Removing outliers of continuous variables using IQR
for(i in 1:ncol(Data)){
  if (cols[i] %in% cont){
    Q3 <- quantile(Data[,i], .75)
    IQR <- IQR(Data[,i])
    Data <- subset(Data, Data[,i]< (Q3 + 3.5*IQR))
  }
}

# Boxplots for discrete variables
discrete <- c("rooms", "floor", "parking.spaces", "bathroom")
for(i in 1:length(discrete)){
  boxplot(Data[, discrete[i]], xlab = discrete[i])
}

#Removing outliers from discrete variables
Data <- subset(Data, floor < 40)
Data <- subset(Data, rooms < 10)
Data <- subset(Data, bathroom < 7)

# Turning variables animal and furniture to 0s and 1s
#Animal
vec <- Data$animal
vec <- as.character(vec)
vec[vec == "acept"] <- 1      # Replace "acept" by 1
vec[vec == "not acept"] <- 0       # Replace "not acept" by 0
vec <- as.factor(vec)
Data$animal <- vec

#Furniture
vec <- Data$furniture
vec <- as.character(vec)
vec[vec == "furnished"] <- 1      # Replace "furnished" by 1
vec[vec == "not furnished"] <- 0       # Replace "not furnished" by 0
vec <- as.factor(vec)
Data$furniture <- vec

#Train test split
# We first split into training and test set, then we split the training set into a smaller training set and a validation set
set.seed(1)
trainrows <- createDataPartition(Data$rent.amount..R.., p=0.8, list=FALSE)
training_set <- Data[trainrows,] # This is saved and will be scaled later to work on the test set
d_test <- Data[-trainrows,]
trainrows <- createDataPartition(training_set$rent.amount..R.., p=0.8, list=FALSE)
d_train <- training_set[trainrows,]
d_val <- training_set[-trainrows,]

unscaled_rent_amounts <- d_test$rent.amount..R.. # Will be saved for later use
mean_tr <- mean(training_set$rent.amount..R..)
std_tr <- sd(training_set$rent.amount..R..)

# Scaling the data
# We make a function that scales the data in dataset using the mean and sd of dataset2
scale_data <- function(dataset, dataset2) {
  for(i in 1:ncol(dataset)){
    if (is.numeric(dataset[1,i])){
      dataset[,i] = scale(dataset[,i], center = mean(dataset2[,i]), scale = sd(dataset2[,i]))
    }
  }
  return(dataset)
} 

# Scaling the training, validation and test sets
d_val <- scale_data(d_val, d_train)
d_test <- scale_data(d_test, training_set)
d_train <- scale_data(d_train, d_train) #Training set last since we use its mean and sd to scale the val set

# Saving unencoded versions of training and validation sets
d_train_unenc <- d_train
d_val_unenc <- d_val

# We make a function to encode the categorical variables in a dataset
encode <- function(dataset, excluded=c()) {
  excluded_cols <- dataset[, names(dataset) %in% excluded]
  dataset <- dataset[,!names(dataset) %in% excluded]
  dmy <- dummyVars(" ~ .", data = dataset)
  dataset <- data.frame(predict(dmy, newdata = dataset))
  dataset <- cbind(dataset, excluded_cols)
  return(dataset)
}  

# Encoding the categorical variables in the training, validation and test sets
d_train <- encode(d_train, c("animal", "furniture"))
d_val <- encode(d_val, c("animal", "furniture"))
d_test <- encode(d_test, c("animal", "furniture"))

# Removing one city (presence of a house in this city would be represented by 0s in the other four city columns, so we can remove one city)
d_train <- subset(d_train, select = -c(city.Campinas))
d_val <- subset(d_val, select = -c(city.Campinas))
d_test <- subset(d_test, select = -c(city.Campinas))

# 5.1 - AIC and BIC
# Implemention of AIC and BIC stepwise selection for multiple regression models
full.model <- lm(rent.amount..R.. ~ ., data = d_train)
step.model.aic <- stepAIC(full.model, direction = "both", trace = 0)

step.model.bic <- stepAIC(full.model, direction = "both", trace = 0, k = log1p(nrow(d_train)))

predictions.aic <- predict(step.model.aic, newdata = d_val)
predictions.bic <- predict(step.model.bic, newdata = d_val)


# Models' performance on the validation set
aic_mse <- mean((predictions.aic - d_val$rent.amount..R..)^2)
bic_mse <- mean((predictions.bic - d_val$rent.amount..R..)^2)
aic_rmse <- sqrt(aic_mse)
bic_rmse <- sqrt(bic_mse)
aic_rsquared <- summary(step.model.aic)$r.squared
bic_rsquared <- summary(step.model.bic)$r.squared

#Data frame to store the evaluation metrics
table <- data.frame(
  Model = character(),  
  MSE = numeric(),
  RMSE = numeric(),
  R_squared = numeric()
)
table <- rbind(table, c("AIC", round(aic_mse, 5), round(aic_rmse, 5), round(aic_rsquared, 5)))
table <- rbind(table, c("BIC", round(bic_mse, 5), round(bic_rmse, 5), round(bic_rsquared, 5)))
colnames(table) <- c("Model", "MSE", "RMSE", "R_squared")

summary(step.model.aic)
summary(step.model.bic)

print(table)

# Residual plots
bicplot <- ggplot(data.frame(Fitted = step.model.bic$fitted.values, Residuals = step.model.bic$residuals), aes(x = Fitted, y = Residuals)) +
  geom_point(color = "blue") + 
  theme_minimal() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(title = "Res vs. Fitted BIC", x = "Fitted Values", y = "Residuals")
aicplot <- ggplot(data.frame(Fitted = step.model.aic$fitted.values, Residuals = step.model.aic$residuals), aes(x = Fitted, y = Residuals)) +
  geom_point(color = "blue") + 
  theme_minimal() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
  labs(title = "Res vs. Fitted AIC", x = "Fitted Values", y = "Residuals")
ggarrange(aicplot,bicplot,nrow = 1,ncol = 2)




# 5.2 - Lasso and Group-Lasso

# Performing 10-fold cross validation
X = model.matrix(rent.amount..R.. ~ ., data=d_train)[,-1]
y = d_train$rent.amount..R..
cvlasso = cv.glmnet(x = X, y = y,nfolds = 10)
groups <- c(1,1,1,1,2,3,4,5,6,7,8,9,10,11)
glasso = cv.gglasso(x=X, y=y, group = groups,nfolds = 10)

# Models' performance on the validation set using the lambda.min and lambda.1se

pen_val <- model.matrix(rent.amount..R.. ~ ., data=d_val)[,-1]
lassopredmin <- predict(cvlasso,pen_val, s = "lambda.min")
lmin_mse <- mean((lassopredmin - d_val$rent.amount..R..)^2)
lmin_rmse <- sqrt(lmin_mse)
lmin_Rsq <- cor(lassopredmin,d_val$rent.amount..R..)^2
lassopred1se <- predict(cvlasso,pen_val, s = "lambda.1se")
lse_mse <- mean((lassopred1se - d_val$rent.amount..R..)^2)

glpred1 <- predict(glasso,pen_val, s="lambda.1se")
gl1_MSE <- mean((glpred1 - d_val$rent.amount..R..)^2)
gl1_Rsq <- cor(glpred1,d_val$rent.amount..R..)^2
glpred2 <- predict(glasso,pen_val, s="lambda.min")
gl2_MSE <- mean((glpred2 - d_val$rent.amount..R..)^2)
gl2_Rsq <- cor(glpred2,d_val$rent.amount..R..)^2

#Data frame to store the evaluation metrics
table <- data.frame(
  Model = character(),  
  MSE = numeric(),
  RMSE = numeric(),
  R_squared = numeric()
)
table <- rbind(table, c("Lasso", round(lmin_mse, 5), round(sqrt(lmin_mse), 5), round(lmin_Rsq, 5)))
table <- rbind(table, c("grLasso", round(gl2_MSE, 5), round(sqrt(gl2_MSE), 5), round(gl2_Rsq, 5)))
colnames(table) <- c("Model", "MSE", "RMSE", "R_squared")
print(table)


# 5.3 - GAM

# Smoothing terms for numerical variables
num_names = names(d_train_unenc)[d_train_unenc %>% map_lgl(is.numeric)]
num_names = num_names %>% 
  discard(~.x %in% c("rent.amount..R.."))
num_feat = num_names %>% 
  map_chr(~paste0("s(", .x, ", 10)")) %>%
  paste(collapse = "+")

# Smoothing terms for categorical variables
cat_feat = names(d_train_unenc)[d_train_unenc %>% map_lgl(is.factor)] %>% 
  paste(collapse = "+")

# GAM formula
gam_form = as.formula(paste0("rent.amount..R.. ~", num_feat, "+", cat_feat))

# Model fitting
fit_gam = gam(formula = gam_form, family = "gaussian", data = d_train_unenc)

# Residuals plot
ggplot(data.frame(Fitted = fit_gam$fitted.values, Residuals = fit_gam$residuals), aes(x = Fitted, y = Residuals)) +
  geom_point(color = "red") + 
  theme_minimal() +
  geom_hline(yintercept = 0, linetype = "dashed", color = "green") +
  labs(title = "Residuals vs Fitted Values", x = "Fitted Values", y = "Residuals")

# Predicting the validation set
predicted_values = predict(fit_gam, d_val_unenc) 

# Evaluation metrics
observed_values = d_val_unenc$rent.amount..R..
gam_mse = mean((predicted_values - observed_values)^2)
gam_rmse = sqrt(gam_mse)
gam_rsquared = cor(predicted_values, observed_values)^2


# 5.4 - XGBoost

# Splitting dependent and independent variables
X_train <- d_train[, !(colnames(d_train) %in% c("rent.amount..R.."))]
y_train <- as.numeric(d_train$rent.amount..R..)

X_val <- d_val[, !(colnames(d_val) %in% c("rent.amount..R.."))]
y_val <- as.numeric(d_val$rent.amount..R..)

#Make sure the columns are numeric before making the xgb.DMatrix that XGBoost is gonna use
for(i in 1:ncol(X_train)){
  X_train[,i] = as.numeric(X_train[,i])
}

for(i in 1:ncol(X_val)){
  X_val[,i] = as.numeric(X_val[,i])
}

# Making the xgb.DMatrices
xgb_train <- xgb.DMatrix(data = as.matrix(X_train), label = y_train)
xgb_val <- xgb.DMatrix(data = as.matrix(X_val))

# Parameter grid for 10-fold cv
param_grid <- expand.grid(
  nrounds = c(100, 200, 300),
  max_depth = c(3, 4, 5),             
  eta = c(0.01, 0.05, 0.1),
  gamma = 0,
  colsample_bytree = 1,
  min_child_weight = 1,  
  subsample = 1   
)
# The other parameters that have a fixed value are included in the grid just because excluding them throws an error when we run cv, 
# however we gave them a fixed value (default value of the model) so that we don't include them in the cross validation process

# 10-fold cross-validation
xgb_model <- train(
  X_train, y_train, 
  method = "xgbTree",
  trControl = trainControl(method = "cv", number = 10),
  tuneGrid = param_grid,
  metric = 'RMSE',
  verbosity = 0
)

# Model fitting
final_model <- xgboost(
  data = xgb_train, 
  nrounds = xgb_model$bestTune$nrounds,
  max_depth = xgb_model$bestTune$max_depth,
  eta = xgb_model$bestTune$eta,
  verbose = 0
)

# Evaluation of the model
predictions <- predict(final_model, newdata = xgb_val)
xgb_mse <- mean((predictions - y_val)^2)
xgb_rmse <- sqrt(xgb_mse)
xgb_rsquared <- 1 - (sum((y_val - predictions)^2) / sum((y_val - mean(y_val))^2))


# 5.5 - Model Selection

#Data frame to store the evaluation metrics
table <- data.frame(
  Model = character(),  
  MSE = numeric(),
  RMSE = numeric(),
  R_squared = numeric()
)

table <- rbind(table, c("BIC", round(bic_mse, 5), round(bic_rmse, 5), round(bic_rsquared, 5)))
table <- rbind(table, c("LASSO", round(lmin_mse, 5), round(lmin_rmse, 5), round(lmin_Rsq, 5)))
table <- rbind(table, c("GAM", round(gam_mse, 5), round(gam_rmse, 5), round(gam_rsquared, 5)))
table <- rbind(table, c("XGBoost", round(xgb_mse, 5), round(xgb_rmse, 5), round(xgb_rsquared, 5)))
colnames(table) <- c("Model", "MSE", "RMSE", "R_squared")

print(table)

# 6 - Prediction on the test set

# Scaling and encoding training set
training_set <- scale_data(training_set, training_set)
training_set <- encode(training_set, c("animal", "furniture"))
training_set <- subset(training_set, select = -c(city.Campinas))

# Splitting dependent and independent variables
X_train <- training_set[, !(colnames(training_set) %in% c("rent.amount..R.."))]
y_train <- as.numeric(training_set$rent.amount..R..)

X_test <- d_test[, !(colnames(d_test) %in% c("rent.amount..R.."))]
y_test <- as.numeric(d_test$rent.amount..R..)

# Making sure the columns are numeric
for(i in 1:ncol(X_train)){
  X_train[,i] = as.numeric(X_train[,i])
}
for(i in 1:ncol(X_val)){
  X_test[,i] = as.numeric(X_test[,i])
}

# Transforming the training and test sets to xgb.Dmatrices
xgb_train <- xgb.DMatrix(data = as.matrix(X_train), label = y_train)
xgb_test <- xgb.DMatrix(data = as.matrix(X_test))

# Model fitting
final_model <- xgboost(
  data = xgb_train, 
  nrounds = xgb_model$bestTune$nrounds,
  max_depth = xgb_model$bestTune$max_depth,
  eta = xgb_model$bestTune$eta,
  verbose = 0
)

# Predicting on the test set
predictions <- predict(final_model, newdata = xgb_test)
unscaled_predictions <- (predictions * std_tr) + mean_tr

# Evaluation of the performance
test_mse <- mean((predictions - y_test)^2)
test_rmse <- sqrt(xgb_mse)
test_rsquared <- 1 - (sum((y_test - predictions)^2) / sum((y_test - mean(y_test))^2))
unscaled_mse <- mean((unscaled_predictions - unscaled_rent_amounts)^2)
unscaled_rmse <- sqrt(unscaled_mse)
print(paste("MSE: ", round(test_mse, 5)))
print(paste("RMSE: ", round(test_rmse, 5), "| RMSE for unscaled predictions", round(unscaled_rmse, 5)))
print(paste("R Squared: ", round(xgb_rsquared, 5)))

# We get the 95% confidence interval for the error of our model
prediction_errors <- unscaled_predictions - unscaled_rent_amounts

# Mean and standard deviation of the prediction errors
mean_error <- mean(prediction_errors)
std_error <- sd(prediction_errors)

# 95% confidence interval for the error
confidence <- 0.95
z_value <- qnorm(1 - (1 - confidence) / 2)
lower_bound <- mean_error - z_value * std_error  # Lower bound of the confidence interval
upper_bound <- mean_error + z_value * std_error  # Upper bound of the confidence interval

cat("Confidence Interval (", confidence * 100, "%): [", lower_bound, ", ", upper_bound, "]\n")

#Feature importance scores
importance_scores <- xgb.importance(
  feature_names = colnames(X_train),
  model = final_model
)

#Plot feature importance
xgb.plot.importance(importance_matrix = importance_scores)

# Scatterplot of Rent Amount vs Fire Insurance
plot(Data$rent.amount..R.., Data$fire.insurance..R.., 
     xlab = "Rent Amount", ylab = "Fire Insurance",
     main = "Scatter Plot of Rent Amount vs Fire Insurance")

# Scatterplot of Rent Amount vs. Insurance by City
ggplot(Data, aes(x = rent.amount..R.., y = fire.insurance..R.., color = city)) +
  geom_point() +
  labs(title = "Rent Amount vs. Insurance by City") +
  xlab("Rent Amount") +
  ylab("Insurance")

# Filtering independent houses and apartments in Belo Horizonte
hoa_zero_data <- subset(Data, Data$city == "Belo Horizonte" & Data$hoa..R.. == 0 & Data$floor == 0)
hoa_nonzero_data <- subset(Data, Data$city == "Belo Horizonte" & Data$hoa..R.. != 0)
hoa_data <- rbind(transform(hoa_zero_data, Group = "Independent"),
                  transform(hoa_nonzero_data, Group = "Condominium"))

# Scatterplot differenciating both groups
ggplot(hoa_data, aes(x = rent.amount..R.., y = fire.insurance..R.., color = Group)) +
  geom_point() +
  labs(title = "Rent Amount vs. Insurance in Belo Horizonte",
       subtitle = "") +
  xlab("Rent Amount") +
  ylab("Insurance")


# 7 - Clustering the houses for rental

#REMOVE CATEGORICAL FEATURES
Data_sc <- Data %>% select_if(is.numeric)
Data_sc <- as.data.frame(scale(Data_sc))

dist_p <- factoextra::get_dist(Data_sc,method = "pearson")
dist_e <- factoextra::get_dist(Data_sc,method = "euclidean")

# Optimal K
set.seed(444)

sil_k <- fviz_nbclust(
  Data_sc,
  FUNcluster = kmeans,
  diss = dist_e,
  method = "silhouette",
  print.summary = TRUE,
  k.max = 10
)
silh <-fviz_nbclust(
  Data_sc,
  FUNcluster = factoextra::hcut,
  diss = dist_e,
  method = "silhouette",
  print.summary = TRUE,
  k.max = 10
)
print(paste("Best k for K-Means(sil):",which(sil_k$data$y == max(sil_k$data$y)),", for HC(sil):",which(silh$data$y == max(silh$data$y))))

wssk <-fviz_nbclust(
  Data_sc,
  FUNcluster = kmeans,
  diss = dist_e,
  method = "wss",
  print.summary = TRUE,
  k.max = 10
)
wssh <-fviz_nbclust(
  Data_sc,
  FUNcluster = hcut,
  diss = dist_e,
  method = "wss",
  print.summary = TRUE,
  k.max = 10
)

# Elbow method plot
ggarrange(wssk,wssh,ncol = 2,nrow = 1)

# Trying with 2 clusters
# kmeans
km2 = kmeans(Data_sc, 2, nstart = 1, iter.max = 1e2)
kmv2 <- fviz_cluster(km2, data = Data_sc, geom = "point", 
                     ggtheme = theme_minimal(), main = "K-Means")

# Evaluating silhouette
library(cluster)
kmv2
sk2 = silhouette(km2$cluster, 
                 dist = dist_e)
sk2v <- fviz_silhouette(sk2,print.summary = FALSE)
print(paste("K-Means AVG Silhouette width:",mean(sk2v$data$sil_width),", totWSS:",km2$tot.withinss))

# Hierarchical
hc2c <- factoextra::hcut(x = dist_e, 
                         k = 4,
                         hc_method = "ward.D2")
e2c <-factoextra::fviz_cluster(list(data = Data_sc, cluster = hc2c$cluster), main = "Hierarchical",labelsize = 0)

e2c # This plots partitions and silhouettes for both

print(paste("Hierarchical's AVG Silhouette width:",hc2c$silinfo$avg.width))
print(paste("Agreement betweenn K-Means and HC",mclust::adjustedRandIndex(km2$cluster,hc2c$cluster)))

# Making 2 dfs for each cluster
clust1 <- Data[which(km2$cluster == 1),]
clust2 <- Data[which(km2$cluster == 2),]

# Avg rent in clust1 (cheaper housing)
# clust2 is more expensive
print(paste("Average rent amount in: Cluster 1:",round(mean(clust1$rent.amount..R..),3),", Cluster 2: ",round(mean(clust2$rent.amount..R..),3)))
print(paste("Percentage of houses in Cluster 1:",round(sum(as.numeric(summary(clust1$city))/nrow(Data)),3),", in Cluster 2:",round(sum(as.numeric(summary(clust2$city))/nrow(Data)),3)))
print(paste("Average property tax in Cluster 1:",round(mean(clust1$property.tax..R..),3),", in Cluster 2:",round(mean(clust2$property.tax..R..),3)))
print(paste("Average rent per room in Cluster 1:",round(mean(clust1$rent.amount..R../clust1$rooms),3),", in Cluster 2:",round(mean(clust2$rent.amount..R../clust2$rooms),3)))

# Pie chart for cities with respect to cluster
display_city_pie_chart <- function(Data, data_name){  
  
  city_df <- as.data.frame(table(Data$city))
  colnames(city_df) <- c("city", "count")
  
  city_df$percentage <- city_df$count / sum(city_df$count)
  
  ggplot(city_df, aes(x = "", y = percentage, fill = city)) +
    geom_bar(width = 1, stat = "identity") +
    coord_polar("y", start = 0) + 
    scale_fill_brewer(palette = "Set3") +
    theme_void() +
    labs(title = paste("Pie Chart of Cities in", data_name), fill = "City")
}

pie1 <- display_city_pie_chart(clust1,"Cluster1")
pie2 <- display_city_pie_chart(clust2,"Cluster2")
ggarrange(pie1,pie2,nrow = 1,ncol = 2)