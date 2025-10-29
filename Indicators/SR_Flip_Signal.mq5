//+------------------------------------------------------------------+
//|                                           Case_Study_Final.mq5 |
//|                                                      Copyright 2025 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "7.00" // Removed Volume Filter, Added HTF Trend Filter
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot for Arrow
#property indicator_label1  "SellSignal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrCrimson
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator Inputs ---
input group "Zone & Breakout Settings"
input color  Support_Zone_Color  = clrDodgerBlue;
input color  Broken_Zone_Color   = clrRed;
input int    ATR_Period          = 7;
input double ATR_Multiplier      = 0.8;
input int    Breakout_Scan_Window= 3;

input group "MA & Signal Settings"
input int    MA_Period           = 10;
input ENUM_MA_METHOD MA_Method   = MODE_SMA;
input int    Breakout_Confirm_Window = 25;
input int    Retest_Confirm_Window   = 15;
input int    MA_Touch_Window     = 5;
input int    Max_Distance_From_MA  = 20;

input group "Higher-Timeframe Filter"
input bool   Use_HTF_Filter      = true;           // Master switch for the HTF filter
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H1;    // Timeframe for trend analysis
input int    HTF_MA_Period       = 20;             // MA period on the higher timeframe

//--- Global Variables ---
string ZonePrefix = "SupportZone_";
int    AtrHandle;
int    MaHandle;
int    HtfMaHandle; // Handle for the HTF Moving Average
double ArrowBuffer[];

//+------------------------------------------------------------------+
int OnInit()
  {
   // --- Current Timeframe Handles ---
   AtrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(AtrHandle == INVALID_HANDLE) { Print("Error creating ATR handle"); return(INIT_FAILED); }
   
   MaHandle = iMA(_Symbol, _Period, MA_Period, 0, MA_Method, PRICE_CLOSE);
   if(MaHandle == INVALID_HANDLE) { Print("Error creating MA handle"); return(INIT_FAILED); }
   
   // --- Higher Timeframe Handle ---
   HtfMaHandle = iMA(_Symbol, HTF_Timeframe, HTF_MA_Period, 0, MA_Method, PRICE_CLOSE);
   if(HtfMaHandle == INVALID_HANDLE) { Print("Error creating HTF MA handle"); return(INIT_FAILED); }

   SetIndexBuffer(0, ArrowBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, ZonePrefix);
   IndicatorRelease(AtrHandle);
   IndicatorRelease(MaHandle);
   IndicatorRelease(HtfMaHandle);
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
   ObjectsDeleteAll(0, ZonePrefix);
   
   // --- Copy Indicator Data ---
   double atrValues[], maValues[];
   if(CopyBuffer(AtrHandle, 0, 0, rates_total, atrValues) <= 0) return(0);
   if(CopyBuffer(MaHandle, 0, 0, rates_total, maValues) <= 0) return(0);
   
   ArraySetAsSeries(ArrowBuffer,false);
   for(int i=0; i<rates_total; i++) ArrowBuffer[i] = 0.0;
   
   for(int i = 1; i < rates_total - 1; i++)
     {
      // --- Find a "Red-then-Green" Support Zone ---
      if(close[i-1] < open[i-1] && close[i] > open[i])
        {
         int zone_start_idx = i - 1;
         double zone_top = close[zone_start_idx];
         double zone_bottom = MathMin(low[zone_start_idx], low[i]);
         
         bool is_broken = false;
         int breakout_bar = -1;
         int breakout_end_check = zone_start_idx + Breakout_Confirm_Window;
         if(breakout_end_check > rates_total -1) breakout_end_check = rates_total - 1;

         for(int k = zone_start_idx + 1; k < breakout_end_check; k++) {
            if(close[k] < zone_bottom) {
               // --- MOMENTUM CHECK ---
               bool has_momentum = false;
               double required_body_size = atrValues[k] * ATR_Multiplier;
               for(int m = k; m >= k - (Breakout_Scan_Window - 1) && m >= 0; m--) {
                  if(close[m] < open[m] && (open[m] - close[m]) > required_body_size) {
                     has_momentum = true;
                     break;
                  }
               }
               
               if(has_momentum) {
                  is_broken = true;
                  breakout_bar = k;
                  break; 
               }
            }
         }
         
         if(is_broken) {
             string zone_name = StringFormat("%s_broken_%d", ZonePrefix, (int)time[zone_start_idx]);
             ObjectCreate(0, zone_name, OBJ_RECTANGLE, 0, time[zone_start_idx], zone_top, time[breakout_bar] + (PeriodSeconds()*5), zone_bottom);
             ObjectSetInteger(0, zone_name, OBJPROP_COLOR, clrRed);
             ObjectSetInteger(0, zone_name, OBJPROP_WIDTH, 1); ObjectSetInteger(0, zone_name, OBJPROP_BACK, true); ObjectSetInteger(0, zone_name, OBJPROP_FILL, false);

             // --- DECOUPLED RETEST & CONFIRMATION LOGIC ---
             int retest_end_check = breakout_bar + Retest_Confirm_Window;
             if(retest_end_check > rates_total - 1) retest_end_check = rates_total - 1;
             
             int retest_peak_idx = -1;
             double retest_peak_high = 0;
             for(int k = breakout_bar + 1; k < retest_end_check; k++) {
                 if(high[k] >= zone_bottom) {
                     if(retest_peak_idx == -1 || high[k] > retest_peak_high) {
                         retest_peak_high = high[k];
                         retest_peak_idx = k;
                     }
                 }
             }

             if(retest_peak_idx != -1) {
                 for(int k = retest_peak_idx; k < retest_end_check; k++) { 
                     if(close[k] < open[k]) {
                         int confirmation_idx = k;
                         
                         // --- LOCAL FILTERS ---
                         bool open_is_valid = (open[confirmation_idx] <= zone_top);
                         bool closed_below_ma = (close[confirmation_idx] <= maValues[confirmation_idx]); 
                         double distance_from_ma = maValues[confirmation_idx] - close[confirmation_idx];
                         bool is_proximate = (distance_from_ma >= 0 && distance_from_ma <= (Max_Distance_From_MA * _Point));
                         
                         bool touched_ma = false;
                         int ma_check_start = confirmation_idx - MA_Touch_Window;
                         if(ma_check_start < 0) ma_check_start = 0;
                         for(int j = confirmation_idx; j >= ma_check_start; j--) {
                             if(high[j] >= maValues[j]) { touched_ma = true; break; }
                         }

                         // --- HIGHER-TIMEFRAME TREND FILTER ---
                         bool htf_trend_is_valid = false;
                         if(!Use_HTF_Filter) {
                            htf_trend_is_valid = true; // Skip if feature is off
                         } else {
                            // Find the corresponding bar on the higher timeframe
                            int htf_shift = iBarShift(_Symbol, HTF_Timeframe, time[confirmation_idx]);
                            double htf_ma_arr[1];
                            // Get the MA value from that single HTF bar
                            if(CopyBuffer(HtfMaHandle, 0, htf_shift, 1, htf_ma_arr) > 0)
                            {
                               double htf_ma_value = htf_ma_arr[0];
                               // Check if the confirmation candle's close is below the HTF MA
                               if(close[confirmation_idx] < htf_ma_value) {
                                  htf_trend_is_valid = true;
                               }
                            }
                         }

                         // If ALL filters (local and HTF) pass, generate the signal
                         if(open_is_valid && closed_below_ma && is_proximate && touched_ma && htf_trend_is_valid) {
                             int arrow_idx = confirmation_idx + 1;
                             if(arrow_idx < rates_total) {
                                 ArrowBuffer[arrow_idx] = high[confirmation_idx] + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
                             }
                             break; 
                         }
                     }
                 }
             }
         } else { 
             string zone_name = StringFormat("%s_held_%d", ZonePrefix, (int)time[zone_start_idx]);
             ObjectCreate(0, zone_name, OBJ_RECTANGLE, 0, time[zone_start_idx], zone_top, time[zone_start_idx] + (PeriodSeconds()*Breakout_Confirm_Window), zone_bottom);
             ObjectSetInteger(0, zone_name, OBJPROP_COLOR, clrDodgerBlue);
             ObjectSetInteger(0, zone_name, OBJPROP_WIDTH, 1); ObjectSetInteger(0, zone_name, OBJPROP_BACK, true); ObjectSetInteger(0, zone_name, OBJPROP_FILL, false);
         }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+