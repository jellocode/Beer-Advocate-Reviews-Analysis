library(dplyr)
library(readr)

df <- read.csv("data.csv")

install.packages("syuzhet")
library(syuzhet)

head(df, 3)
tail(df, 3)
dim(df)
names(df)

summary(df)
str(df)

# check unique cols in df
unique_cols <- sapply(df, function(col) length(unique(col)) == length(col))
print(names(df)[unique_cols])

# Null values
# check null counts
colSums(is.na(df))

# drop null values
df <- na.omit(df)
colSums(is.na(df))

dim(df)

# Remove duplicate data

head(df$review_profileName)

# sort by "review_overall" in descending order
df <- df %>% arrange(desc(review_overall))

# keep the highest rating from each "review_profileName" and drop the rest
df <- df %>% distinct(review_profileName, beer_beerId, .keep_all = TRUE)

# print the dimensions of the dataframe
dim(df)

# 1. Rank top 3 Breweries which produce the strongest beers?

# group by brewerId and calculate the average ABV for each brewery
brewery_avg_abv <- df %>%
group_by(beer_brewerId) %>%
summarize(avg_abv = mean(beer_ABV, na.rm = TRUE))

# sort breweries by average ABV in descending order and select the top 3
top_3_breweries <- brewery_avg_abv %>%
arrange(desc(avg_abv)) %>%
head(3)

# print the top 3 breweries producing the strongest beers
cat("Top 3 Breweries Producing the Strongest Beers:\n")
print(top_3_breweries)

# 2. Which year did beers enjoy the highest ratings?

# Convert review_time to datetime
df$review_time <- as.POSIXct(df$review_time, origin = "1970-01-01", tz = "UTC")

# extract year from review_time
df$year <- as.integer(format(df$review_time, "%Y"))

# group by year and calculate the average rating for each year
average_ratings_by_year <- aggregate(review_overall ~ year, data = df, FUN = mean, na.rm = TRUE)

# find the year with the highest average rating
highest_rated_year <- average_ratings_by_year[which.max(average_ratings_by_year$review_overall), "year"]

cat("Year with the highest average ratings for beers:", highest_rated_year, "\n")

# 3. Based on the user’s ratings which factors are important among taste, aroma, appearance, and palette?

# select columns for correlation calculation
correlation_cols <- c('review_taste', 'review_aroma', 'review_appearance', 'review_palette', 'review_overall')
correlation_df <- df[, correlation_cols]

# calculate correlation matrix
correlation_matrix <- cor(correlation_df)

# extract correlations with review_overall
correlations_with_overall <- correlation_matrix['review_overall', ]

# remove correlation with review_overall
correlations_with_overall <- correlations_with_overall[correlations_with_overall != 1]

# sort correlations in descending order
sorted_correlations <- sort(correlations_with_overall, decreasing = TRUE)

# print correlations
cat("Correlation between each factor and overall review rating:\n")
print(sorted_correlations)

# so review_aroma has highest corellation which is important

# 4. If you were to recommend 3 beers to your friends based on this data which ones will you recommend?
# define custom weights
weights <- c(review_overall = 0.4, review_taste = 0.2, review_aroma = 0.1, review_appearance = 0.1, review_palette = 0.2)

# calculate weighted rating
df$weighted_rating <- rowSums(df[, names(weights)] * weights)

# sort beers by weighted rating in descending order
recommended_beers <- df[order(-df$weighted_rating), ]

# select top 3 recommended beers
recommended_beers <- head(recommended_beers, 3)

# print recommended beers
cat("Recommended beers for my friends:\n")
print(recommended_beers[, c("beer_name", "weighted_rating")])

"how the weights were decided:
Review Overall: represents the overall review rating given by users. Since it reflects the overall satisfaction with the beer; highest weight of 0.4
Review Taste: taste is a crucial aspect of beer enjoyment; 0.2, reflecting its importance in the overall rating
Review Aroma: aroma contributes significantly to the sensory experience of drinking beer, but it may be slightly less important than taste; 0.1
Review Appearance: can influence the initial impression of a beer, overall enjoyment may be lower compared to taste and aroma; 0.1
Review Palette: mouthfeel or texture of the beer; 0.2"

# 5. Which Beer style seems to be the favorite based on reviews written by users?, 6. How does written review compare to overall review score for the beer styles?

# select relevant columns
reviewTextData <- df[, c('beer_beerId', 'beer_name', 'beer_ABV', 'beer_style', 'review_overall', 'review_text')]

# filter rows with review_overall >= 4
reviewTextData <- reviewTextData[reviewTextData$review_overall >= 4, ]

# reset index
rownames(reviewTextData) <- NULL

# print the first few rows
print(head(reviewTextData))

reviewTextData$review_text[8]

# text preprocessing: replacing contractions with their full forms
decontracted <- function(phrase) {
  # Specific contractions
  phrase <- gsub("won't", "will not", phrase)
  phrase <- gsub("can't", "can not", phrase)
  phrase <- gsub("it's", "it is", phrase)
  
  # general contractions
  phrase <- gsub("n't", " not", phrase)
  phrase <- gsub("'re", " are", phrase)
  phrase <- gsub("'s", " is", phrase)
  phrase <- gsub("'d", " would", phrase)
  phrase <- gsub("'ll", " will", phrase)
  phrase <- gsub("'t", " not", phrase)
  phrase <- gsub("'ve", " have", phrase)
  phrase <- gsub("'m", " am", phrase)
  
  return(phrase)
}

# Define an empty list to store preprocessed reviews
preprocessed_reviews <- c()

# Loop through each review text
for (sentence in reviewTextData$review_text) {
  sentence <- decontracted(sentence)
  
  # remove words with numbers
  sentence <- gsub("\\S*\\d\\S*", "", sentence)
  
  sentence <- trimws(sentence)
  preprocessed_reviews <- c(preprocessed_reviews, sentence)
}

preprocessed_reviews[8] # check that's to that is

# append preprocessed reviews to the filtered dataframe
reviewTextData$preprocessed_review_text <- preprocessed_reviews

# calculate polarity score for each review
reviewTextData$polarity_score2 <- get_sentiment(reviewTextData$preprocessed_review_text, method = "syuzhet")

# group by beer_style and calculate mean polarity score
reviewTextDataGroupped <- reviewTextData %>%
  group_by(beer_style) %>%
  summarize(mean_polarity_score = mean(polarity_score2, na.rm = TRUE))

# sort the grouped data by mean polarity score
top_5_styles <- reviewTextDataGroupped %>%
  arrange(desc(mean_polarity_score)) %>%
  head(5)

print(top_5_styles)

reviewTextData[reviewTextData$beer_style == 'Dortmunder / Export Lager', ]
reviewTextData[reviewTextData$beer_style == 'Extra Special / Strong Bitter (ESB)', ]

# 7. How to find similar beer drinkers by using written reviews only?
library(tm)
library(proxy)
# Create a term-document matrix using TF-IDF
tdm <- DocumentTermMatrix(Corpus(VectorSource(reviewTextData$preprocessed_review_text)),
                          control = list(weighting = function(x) weightTfIdf(x, normalize = TRUE)))

# Convert the term-document matrix to a matrix
tfidf_matrix <- as.matrix(tdm)
# Calculate cosine similarity between user reviews
cosine_similarities <- proxy::simil(tfidf_matrix, tfidf_matrix, method = "cosine", upper = TRUE)

# Load necessary library
library(stats)

# assume cosine_similarities is the cosine similarity matrix between user reviews

# grouping together similar customers based on reviews
kmeans_model <- kmeans(cosine_similarities, centers = 8)
clusters <- kmeans_model$cluster

# analyze cluster assignments
# assign each user to a cluster
user_clusters <- list()

for (user_id in 1:length(clusters)) {
  cluster_id <- clusters[user_id]
  if (!(as.character(cluster_id) %in% names(user_clusters))) {
    user_clusters[[as.character(cluster_id)]] <- c()
  }
  user_clusters[[as.character(cluster_id)]] <- c(user_clusters[[as.character(cluster_id)]], user_id)
}

# print the users in each cluster
for (cluster_id in names(user_clusters)) {
  cat(paste("Cluster", cluster_id, ":", user_clusters[[cluster_id]], "\n"))
}

# visualisation of clusters
# install necessary libraries
install.packages("ggplot2")
install.packages("pracma")

# load necessary libraries
library(ggplot2)
library(pracma)

# perform PCA on the TF-IDF matrix
pca_result <- prcomp(tfidf_matrix, center = TRUE, scale. = TRUE)

# extract PCA scores
pca_scores <- pca_result$x

# create a data frame with PCA scores and cluster assignments
pca_data <- data.frame(PC1 = pca_scores[,1], PC2 = pca_scores[,2], Cluster = as.factor(clusters))

# plot clusters
ggplot(pca_data, aes(x = PC1, y = PC2, color = Cluster)) +
  geom_point() +
  labs(title = "Cluster Visualization using PCA",
       x = "Principal Component 1",
       y = "Principal Component 2")

