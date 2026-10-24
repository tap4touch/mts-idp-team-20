from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = (SparkSession.builder
         .appName("HW4 - Spark Transformations")
         .getOrCreate())

schema = "order_id BIGINT, order_ts TIMESTAMP, customer_id INT, category STRING, quantity INT, price DECIMAL(10,2), dt STRING"

raw_df = (spark.read
          .option("header", True)
          .schema(schema)
          .option("mode", "DROPMALFORMED")
          .csv("/demo/spark_hw/orders_raw"))

transformed_df = (raw_df
                  .filter(F.col("order_id").isNotNull())
                  .withColumn("revenue", F.round(F.col("quantity") * F.col("price"), 2))
                  .groupBy("dt", "category")
                  .agg(
                      F.count("*").alias("total_orders"),
                      F.sum("revenue").cast("double").alias("total_revenue")
                  ))

(transformed_df.write
 .mode("overwrite")
 .format("parquet")
 .partitionBy("dt")
 .save("/demo/spark_hw/revenue_by_category"))

print("Spark job completed successfully.")
spark.stop()
