# ============================================================================
# PROJECT: AI-Powered Customer Churn Analytics & Lifetime Value Predictor
# COMPONENT: Phase 2 - Production ML Pipelines with Model Serialization (.pkl)
# DESCRIPTION: Optimizes XGBoost models and exports serialized artifacts.
# ============================================================================

import os
import sys
import subprocess

# 1. Programmatically verify and install dependencies before running imports
print("📦 Verifying project environment dependencies configuration...")
try:
    import xgboost
except ImportError:
    print("⚠️ xgboost missing from cluster node. Initiating automated bootstrap install...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "xgboost==2.1.1"])
    print("✅ xgboost dependency successfully injected programmatically.")

# 2. Safe Imports (Executed only after dependencies are verified)
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import classification_report, mean_absolute_error, r2_score, accuracy_score
from xgboost import XGBClassifier, XGBRegressor
import joblib

class DatabricksSerializedMLPipeline:
    def __init__(self):
        self.numeric_features = [
            'tenure_months', 'current_monthly_rev', 'failed_payments_30d', 
            'total_logins_30d', 'total_duration_30d', 'login_velocity_30d', 
            'support_tickets_30d', 'high_priority_tickets_30d'
        ]
        self.categorical_features = ['segment', 'acquisition_channel', 'country']
        self.preprocessor = None
        self.best_churn_model = None
        self.clv_model = None

    def build_transformer(self):
        """Creates an enterprise preprocessor handling scaling and encoding uniformly."""
        return ColumnTransformer(
            transformers=[
                ('num', StandardScaler(), self.numeric_features),
                ('cat', OneHotEncoder(handle_unknown='ignore'), self.categorical_features)
            ])

    def execute_tuning_and_training(self, df):
        """Runs hyperparameter optimization on Churn and trains the CLV model."""
        print("💡 Step 1: Parsing feature vectors and engineering splits...")
        X = df[self.numeric_features + self.categorical_features]
        y_churn = df['target_churned_next_month']
        y_clv = df['current_monthly_rev'] * (df['tenure_months'] + 1)

        X_train, X_test, y_train_churn, y_test_churn, y_train_clv, y_test_clv = train_test_split(
            X, y_churn, y_clv, test_size=0.2, random_state=42
        )

        self.preprocessor = self.build_transformer()

        # ============================================================================
        # CHURN MODEL: HYPERPARAMETER TUNING
        # ============================================================================
        print("🔍 Step 2: Initializing Hyperparameter Tuning via GridSearchCV for Churn...")
        base_churn_pipeline = Pipeline(steps=[
            ('preprocessor', self.preprocessor),
            ('classifier', XGBClassifier(random_state=42, eval_metric='logloss'))
        ])
        
        param_grid = {
            'classifier__n_estimators':[50,100,150,200],
            'classifier__max_depth':[3,4,5,6,8],
            'classifier__learning_rate': [0.05, 0.1]
        }
        
        grid_search = GridSearchCV(
            estimator=base_churn_pipeline,
            param_grid=param_grid,
            cv=3,
            scoring='accuracy',
            verbose=1,
            n_jobs=-1
        )
        
        print("🏋️ Running grid cross-validation across tuning matrices...")
        grid_search.fit(X_train, y_train_churn)
        self.best_churn_model = grid_search.best_estimator_
        
        # Evaluate Churn Model
        churn_preds = self.best_churn_model.predict(X_test)
        print(f"\n🏆 Optimized Accuracy Score: {accuracy_score(y_test_churn, churn_preds):.4f}")

        # ============================================================================
        # CLV REGRESSOR TRAINING
        # ============================================================================
        print("🤖 Training Customer Lifetime Value Regressor...")
        self.clv_model = Pipeline(steps=[
            ('preprocessor', self.preprocessor),
            ('regressor', XGBRegressor(n_estimators=150, max_depth=6, learning_rate=0.03, random_state=42))
        ])
        self.clv_model.fit(X_train, y_train_clv)

        # ============================================================================
        # PRODUCTION SERIALIZATION EXPORT STEP (.pkl)
        # ============================================================================
        print("💾 Step 3: Serializing model architecture pipelines to disk...")
        joblib.dump(self.best_churn_model, 'churn_classifier_model.pkl')
        joblib.dump(self.clv_model, 'clv_regressor_model.pkl')
        print("📌 Churn model artifact written to: churn_classifier_model.pkl")
        print("📌 CLV model artifact written to: clv_regressor_model.pkl")

        return X

    def generate_production_scores(self, X_features, original_pandas_df):
        """Scores full tables using the newly tuned optimization matrix."""
        print("💾 Running optimized inference engine across dataset...")
        churn_probabilities = self.best_churn_model.predict_proba(X_features)[:, 1]
        predicted_clv_values = self.clv_model.predict(X_features)
        
        scored_df = original_pandas_df.copy()
        scored_df['churn_risk_score'] = churn_probabilities
        scored_df['predicted_lifetime_value'] = predicted_clv_values
        
        scored_df['risk_tier'] = pd.cut(
            scored_df['churn_risk_score'], 
            bins=[-0.1, 0.3, 0.7, 1.1], 
            labels=['Low Risk', 'Medium Risk', 'High Risk']
        )
        return scored_df

# ============================================================================
# RUNTIME AUTOMATION EXECUTOR (With Terminal Matrix Printing)
# ============================================================================
if __name__ == "__main__":
    print("🚀 Initializing Databricks AI Pipeline Driver context...")
    
    # Programmatically verify and install dependencies before running imports
    import os
    import sys
    import subprocess
    
    print("📦 Verifying project environment dependencies configuration...")
    try:
        import xgboost
    except ImportError:
        print("⚠️ xgboost missing from cluster node. Initiating automated bootstrap install...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "xgboost==2.1.1"])
        print("✅ xgboost dependency successfully injected programmatically.")

    # 1. Query the feature store table natively from Delta Lake
    raw_spark_df = spark.sql("SELECT * FROM customer_churn_analytics.analytics_feature_store")
    pandas_features_df = raw_spark_df.toPandas()
    
    # 2. Re-trigger model validation pipeline runs
    pipeline_manager = DatabricksSerializedMLPipeline()
    feature_matrix = pipeline_manager.execute_tuning_and_training(pandas_features_df)
    
    # 3. Explicitly extract test evaluation metrics to print directly to terminal console
    from sklearn.model_selection import train_test_split
    from sklearn.metrics import classification_report, accuracy_score
    
    X = pandas_features_df[pipeline_manager.numeric_features + pipeline_manager.categorical_features]
    y_churn = pandas_features_df['target_churned_next_month']
    _, X_test, _, y_test_churn = train_test_split(X, y_churn, test_size=0.2, random_state=42)
    
    # 4. Generate classifications from the best optimized estimator
    churn_preds = pipeline_manager.best_churn_model.predict(X_test)
    
    # 5. MANDATORY TERMINAL PRINT OUT LOGS
    print("\n" + "="*50)
    print("   TERMINAL DISPLAY: CLASSIFICATION PERFORMANCE MATRIX")
    print("="*50)
    print(f"Optimized Accuracy Score: {accuracy_score(y_test_churn, churn_preds):.4f}\n")
    print(classification_report(y_test_churn, churn_preds))
    print("="*50 + "\n")
    
    # 6. Score full array layout and write table back to Delta Lake storage
    final_scored_pandas_df = pipeline_manager.generate_production_scores(feature_matrix, pandas_features_df)
    final_spark_output_df = spark.createDataFrame(final_scored_pandas_df)
    
    final_spark_output_df.write \
        .format("delta") \
        .mode("overwrite") \
        .option("overwriteSchema", "true") \
        .saveAsTable("customer_churn_analytics.final_predictions_output")
        
    print("✅ Hyperparameter Tuning, Serialization, & Pipeline Execution fully completed!")
