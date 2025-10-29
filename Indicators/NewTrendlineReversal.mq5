//+------------------------------------------------------------------+
//|                               Final_Bearish_Trendline_Signal.mq5 |
//|                                                      Copyright 2025 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.02" // Corrected syntax errors
#property description "FINAL: Generates a bearish arrow and PERMANENT trendline for valid setups."

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot for Arrow
#property indicator_label1  "SellSignal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator Inputs ---
input group "Moving Average Settings"
input int    MA_Period          = 10;
input ENUM_MA_METHOD MA_Method  = MODE_SMA;

input group "Trendline Search Settings"
input int    LookbackPeriod     = 200;
input int    TouchLookback      = 5;
input int    ProximityPoints    = 30;
input int    ToleranceInPoints  = 10;

input group "Visualization Settings"
input color  TrendlineColor     = clrGold;

//--- Global Variables ---
int    MaHandle;
double ArrowBuffer[];
string TrendlinePrefix = "Final_Bearish_TL_";

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
   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   ObjectsDeleteAll(0, TrendlinePrefix);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   ObjectsDeleteAll(0, TrendlinePrefix);
}
//+------------------------------------------------------------------+
//| THIS ENTIRE FUNCTION HAS BEEN REWRITTEN WITH CORRECT SYNTAX      |
//+------------------------------------------------------------------+
void FindAndDrawSignalForBar(int C_idx, const datetime &time[], const double &open[], const double &high[], const double &low[], const double &close[], const double &maValues[], double &arrow_buffer[])
{
    if(C_idx < 1) return;
    if(close[C_idx] >= open[C_idx]) return;
    if(close[C_idx] > maValues[C_idx] || (maValues[C_idx] - close[C_idx]) > (ProximityPoints * _Point)) return;
    bool ma_touched = false;
    for(int k = C_idx; k >= C_idx - TouchLookback && k >= 0; k--) {
        if(high[k] >= maValues[k]) { ma_touched = true; break; }
    }
    if(!ma_touched) return;
    if(C_idx > 0 && close[C_idx-1] < open[C_idx-1]) return;

    double tolerance = ToleranceInPoints * _Point;
    bool signalFound = false;

    for(int B_idx = C_idx - 3; B_idx > 0 && B_idx > C_idx - LookbackPeriod; B_idx--) {
        if(high[B_idx] > high[B_idx+1] && high[B_idx] > high[B_idx-1]) {
            for(int A_idx = B_idx - 2; A_idx >= 0 && A_idx > C_idx - LookbackPeriod; A_idx--) {
                if(high[A_idx] > high[A_idx+1] && high[A_idx] > high[A_idx-1]) {
                    if(!(high[A_idx] > high[B_idx] && high[B_idx] > high[C_idx])) continue;
                    if(low[A_idx] <= maValues[A_idx]) continue;

                    double c_anchors[2] = {high[C_idx], MathMax(open[C_idx], close[C_idx])};
                    double b_anchors[2] = {high[B_idx], MathMax(open[B_idx], close[B_idx])};
                    double a_anchors[2] = {high[A_idx], MathMax(open[A_idx], close[A_idx])};

                    for(int c_type = 0; c_type < 2; c_type++) {
                        for(int b_type = 0; b_type < 2; b_type++) {
                            for(int a_type = 0; a_type < 2; a_type++) {
                                if(IsOnLine(time[A_idx], a_anchors[a_type], time[B_idx], b_anchors[b_type], time[C_idx], c_anchors[c_type], tolerance)) {
                                    bool line_held = true;
                                    for(int k = A_idx + 1; k < C_idx; k++) {
                                        double line_price_at_k = a_anchors[a_type] + (double(time[k] - time[A_idx]) / (double)(time[C_idx] - time[A_idx])) * (c_anchors[c_type] - a_anchors[a_type]);
                                        if(close[k] > line_price_at_k + tolerance) { line_held = false; break; }
                                    }
                                    
                                    if(line_held) {
                                        arrow_buffer[C_idx + 1] = high[C_idx] + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15);
                                        string objName = TrendlinePrefix + IntegerToString(time[C_idx]);
                                        ObjectCreate(0, objName, OBJ_TREND, 0, time[A_idx], a_anchors[a_type], time[C_idx], c_anchors[c_type]);
                                        ObjectSetInteger(0, objName, OBJPROP_COLOR, TrendlineColor);
                                        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
                                        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
                                        signalFound = true;
                                        break; // Break from a_type loop
                                    }
                                }
                            } // End a_type loop
                            if(signalFound) break; // Break from b_type loop
                        } // End b_type loop
                        if(signalFound) break; // Break from c_type loop
                    } // End c_type loop
                } // End if A is swing high
                if(signalFound) break; // Break from A_idx loop
            } // End A_idx loop
        } // End if B is swing high
        if(signalFound) break; // Break from B_idx loop
    } // End B_idx loop
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
   int bars_to_process;
   if(prev_calculated == 0) {
      bars_to_process = rates_total - 1;
   } else {
      bars_to_process = rates_total - prev_calculated + 1;
   }
   if (bars_to_process > rates_total - LookbackPeriod - 1) bars_to_process = rates_total - LookbackPeriod - 1;

   double maValues[];
   if(CopyBuffer(MaHandle, 0, 0, rates_total, maValues) <= 0) return(rates_total);

   for(int i = rates_total - bars_to_process; i < rates_total; i++)
     {
      ArrowBuffer[i] = 0.0;
      if(i > LookbackPeriod)
        {
         FindAndDrawSignalForBar(i, time, open, high, low, close, maValues, ArrowBuffer);
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+