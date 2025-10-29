//+------------------------------------------------------------------+
//|                        DEBUG_TrendlineFlip_Visualizer.mq5 |
//|                                                      Copyright 2025 |
//|                                       For strategy development      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property description "DEBUG: Draws all valid 'Flipped Support' bearish trendlines."

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Indicator Inputs ---
input group "Moving Average Settings"
input int    MA_Period          = 10;
input ENUM_MA_METHOD MA_Method  = MODE_SMA;

input group "Trendline Search Settings"
input int    LookbackPeriod     = 200;
input int    ToleranceInPoints  = 5;

input group "Visualization Settings"
input color  TrendlineColor     = clrGold;

//--- Global Variables ---
int    MaHandle;
string TrendlinePrefix = "DEBUG_TL_Flip_";

//+------------------------------------------------------------------+
bool IsOnLine(long t1, double p1, long t2, double p2, long t3, double p3, double tolerance) {
   if(t2 == t1) return false;
   double expected_p3 = p1 + (double(t3 - t1) / (double)(t2 - t1)) * (p2 - p1);
   if(MathAbs(p3 - expected_p3) <= tolerance) return true;
   return false;
}
//+------------------------------------------------------------------+
int OnInit() {
   MaHandle = iMA(_Symbol, _Period, MA_Period, 0, MA_Method, PRICE_CLOSE);
   if(MaHandle == INVALID_HANDLE) { Print("Error creating MA handle"); return(INIT_FAILED); }
   ObjectsDeleteAll(0, TrendlinePrefix);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, TrendlinePrefix);
}
//+------------------------------------------------------------------+
void FindAndDrawFlipLinesForBar(int C_idx, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const double &maValues[])
{
    // === STEP 1: FIND THE TRIGGER EVENT (Reversal at the MA) ===
    if(close[C_idx] >= open[C_idx] || high[C_idx] < maValues[C_idx] || close[C_idx] >= maValues[C_idx]) {
        return; // Not a valid bearish confirmation candle at the MA
    }

    double tolerance = ToleranceInPoints * _Point;

    // Outer loop to find Point B (a swing low)
    for(int B_idx = C_idx - 3; B_idx > C_idx - LookbackPeriod && B_idx > 1; B_idx--) {
        if(low[B_idx] < low[B_idx+1] && low[B_idx] < low[B_idx-1]) {
            // Inner loop to find Point A (a swing low)
            for(int A_idx = B_idx - 2; A_idx > C_idx - LookbackPeriod && A_idx >= 0; A_idx--) {
                if(low[A_idx] < low[A_idx+1] && low[A_idx] < low[A_idx-1]) {
                    
                    // --- A-B-C Triplet found. Run the "best fit" check ---
                    // Correct anchors for Point C (High and Top of Body)
                    double c_anchors[2] = {high[C_idx], MathMax(open[C_idx], close[C_idx])};
                    // Anchors for support points A and B (Low and Bottom of Body)
                    double b_anchors[2] = {low[B_idx], MathMin(open[B_idx], close[B_idx])};
                    double a_anchors[2] = {low[A_idx], MathMin(open[A_idx], close[A_idx])};
                  
                    for(int c_type=0; c_type<2; c_type++)
                    for(int b_type=0; b_type<2; b_type++)
                    for(int a_type=0; a_type<2; a_type++) {
                        if(IsOnLine(time[A_idx], a_anchors[a_type], time[B_idx], b_anchors[b_type], time[C_idx], c_anchors[c_type], tolerance)) {
                            
                            // === CRUCIAL FILTER: CONFIRM THE BREAKOUT ===
                            bool breakout_confirmed = false;
                            for(int k = B_idx + 1; k < C_idx; k++) {
                                double line_price_at_k = a_anchors[a_type] + (double(time[k] - time[A_idx]) / (double)(time[B_idx] - time[A_idx])) * (b_anchors[b_type] - a_anchors[a_type]);
                                if(close[k] < line_price_at_k - tolerance) { // Check if price closed decisively below
                                    breakout_confirmed = true;
                                    break;
                                }
                            }

                            if(breakout_confirmed) {
                                // --- SUCCESS! Draw the trendline ---
                                string objName = TrendlinePrefix + IntegerToString(time[C_idx]) + "_" + IntegerToString(time[B_idx]) + "_" + IntegerToString(time[A_idx]) + "_" + IntegerToString(a_type)+IntegerToString(b_type)+IntegerToString(c_type);
                                ObjectCreate(0, objName, OBJ_TREND, 0, time[A_idx], a_anchors[a_type], time[C_idx], c_anchors[c_type]);
                                ObjectSetInteger(0, objName, OBJPROP_COLOR, TrendlineColor);
                                ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
                                ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                            }
                        }
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Use the new, efficient calculation engine
   int bars_to_process;
   if(prev_calculated == 0) {
      bars_to_process = rates_total - 1;
   } else {
      bars_to_process = rates_total - prev_calculated;
   }
   if (bars_to_process > rates_total - LookbackPeriod - 1) bars_to_process = rates_total - LookbackPeriod - 1;

   double maValues[];
   if(CopyBuffer(MaHandle, 0, 0, rates_total, maValues) <= 0) return(rates_total);

   for(int i = rates_total - bars_to_process - 1; i < rates_total -1; i++) {
      if(i > LookbackPeriod) {
         FindAndDrawFlipLinesForBar(i, time, open, high, low, close, maValues);
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+