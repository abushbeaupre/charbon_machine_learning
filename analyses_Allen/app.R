# Charbon (Onion Smut) Risk Predictor — Shiny app template
#
# This app is meant to be handed to non-technical end users (producers,
# agronomists): they fill in a form with field/weather values, and the app
# shows predicted disease-incidence risk for each threshold (1-5%).
#
# TODO before deploying:
#   1. Fit each finalized workflow (from 02_modeling_template.qmd) on ALL
#      available training data (not just the CV folds) and save each one,
#      e.g.:
#        final_model_1 <- fit(final_wf, data = train)  # threshold 1%, repeat per threshold/model
#        write_rds(final_model_1, "model_threshold_1.rds")
#      Do this once per threshold (1-5%), using whichever of tree/rf/boost
#      won for that threshold — they need not all use the same model type.
#   2. Update MODEL_PATHS below to point at the five saved .rds files.
#   3. Update the `inputs` list and `build_new_data()` function below to
#      match the actual predictor columns kept in the final recipe (i.e.
#      whatever remains in `train` after dropping leakage columns in
#      02_modeling_template.qmd) — the placeholders below are illustrative
#      based on columns seen during exploration, not final decisions.

library(shiny)
library(bslib)
library(tidymodels)

# ---- Load the finalized, fitted models (one per threshold) ----------------
# TODO: replace with the real paths once models are fit and saved (step 1
# above). Keeping all five in a named list lets the UI/server code below
# loop over thresholds instead of repeating itself five times.
MODEL_PATHS <- list(
  "1%" = "model_threshold_1.rds",
  "2%" = "model_threshold_2.rds",
  "3%" = "model_threshold_3.rds",
  "4%" = "model_threshold_4.rds",
  "5%" = "model_threshold_5.rds"
)

# Load once at app startup rather than per-request, since the fitted
# workflow objects don't change between requests and reloading from disk on
# every prediction would be wasteful.
# TODO: uncomment once the .rds files above exist.
# models <- lapply(MODEL_PATHS, read_rds)
models <- list()  # placeholder so the app runs before models are trained

# ---- UI ---------------------------------------------------------------

# TODO: adjust these inputs to match the actual predictor set. Grouping into
# a sidebar keeps the form organized for a non-technical user; adjust
# labels to plain-language descriptions of each predictor (avoid raw column
# names / French abbreviations in the UI text where possible).
ui <- page_sidebar(
  title = "Charbon (Onion Smut) Risk Predictor",
  theme = bs_theme(version = 5),
  sidebar = sidebar(
    title = "Field information",
    width = 350,

    selectInput(
      "cultivar", "Cultivar",
      choices = c("TODO: fill in with actual cultivar levels")
    ),
    selectInput(
      "traitement_de_semences", "Seed treatment",
      choices = c("TODO: fill in with actual treatment levels")
    ),
    numericInput(
      "spores_g_sol", "Soil spore load (spores / g soil)",
      value = 0, min = 0, step = 1
    ),
    numericInput(
      "semi_se_temp_air", "Mean air temperature, sowing to flag-leaf stage (°C)",
      value = 15, step = 0.5
    ),
    numericInput(
      "semi_se_pluie", "Total rainfall, sowing to flag-leaf stage (mm)",
      value = 50, min = 0, step = 1
    ),
    # TODO: add remaining predictors here (dates, station, producer, etc.)
    # as needed once the final predictor set is confirmed.

    actionButton("predict_btn", "Predict risk", class = "btn-primary")
  ),

  card(
    card_header("Predicted risk of exceeding each incidence threshold"),
    tableOutput("predictions_table"),
    p(
      class = "text-muted",
      "Risk is the model's estimated probability that disease incidence in ",
      "this field will exceed the given threshold. These are statistical ",
      "estimates, not guarantees — use alongside other field observations ",
      "and expert judgment."
    )
  )
)

# ---- Server -------------------------------------------------------------

server <- function(input, output, session) {

  # Collect the current form inputs into a one-row data frame with the same
  # column names/types the models were trained on. TODO: extend to include
  # every predictor added to the sidebar above.
  build_new_data <- reactive({
    tibble(
      cultivar                = input$cultivar,
      traitement_de_semences  = input$traitement_de_semences,
      spores_g_sol            = input$spores_g_sol,
      semi_se_temp_air        = input$semi_se_temp_air,
      semi_se_pluie           = input$semi_se_pluie
      # TODO: add remaining predictor columns here, matching build_new_data
      # column names exactly to the training data's column names.
    )
  })

  predictions <- eventReactive(input$predict_btn, {
    new_data <- build_new_data()

    # TODO: remove this guard once `models` is populated from MODEL_PATHS.
    validate(need(
      length(models) > 0,
      "No models loaded yet — see MODEL_PATHS/TODOs at the top of app.R."
    ))

    # predict(..., type = "prob") returns predicted class probabilities;
    # we keep the probability of the "above" class as the risk estimate for
    # each threshold's model.
    purrr::imap_dfr(models, function(model, threshold_label) {
      probs <- predict(model, new_data, type = "prob")
      tibble(
        Threshold = threshold_label,
        `Predicted risk (%)` = round(100 * probs$.pred_above, 1),
        `Predicted class` = predict(model, new_data, type = "class")$.pred_class
      )
    })
  })

  output$predictions_table <- renderTable({
    predictions()
  })
}

shinyApp(ui, server)
