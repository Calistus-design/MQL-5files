//+------------------------------------------------------------------+
//|                                       SignalCandleIdentifier.mq5 |
//|                                                      Copyright 2025 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot for Bullish Arrows (Hammers)
#property indicator_label1  "HammerSignal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot for Bearish Arrows (Shooting Stars)
#property indicator_label2  "ShootingStarSignal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Indicator Buffers ---
double HammerBuffer[];
double ShootingStarBuffer[];

//--- Indicator Inputs ---
input double WickToBodyRatio = 2.0; // The wick must be at least X times the body size

//+------------------------------------------------------------------+
int OnInit()
  {
//--- Map Hammer Buffer
   SetIndexBuffer(0, HammerBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

//--- Map Shooting Star Buffer
   SetIndexBuffer(1, ShootingStarBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   return(INIT_SUCCEEDED);
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
   //--- Start calculation from the first complete bar
   int start = prev_calculated > 1 ? prev_calculated - 1 : 1;

   //--- Main loop to check every candle
   for(int i = start; i < rates_total; i++)
     {
      // Set default empty values
      HammerBuffer[i] = 0.0;
      ShootingStarBuffer[i] = 0.0;

      //--- Calculate candle components ---
      double bodySize = MathAbs(open[i] - close[i]);
      double upperWick = high[i] - MathMax(open[i], close[i]);
      double lowerWick = MathMin(open[i], close[i]) - low[i];
      
      // We need a body to make a comparison
      if(bodySize <= 0) continue;

      //--- Hammer Identification Logic ---
      // 1. Lower wick is long (at least WickToBodyRatio * bodySize)
      // 2. Upper wick is very small (less than half the body size, for example)
      if(lowerWick >= bodySize * WickToBodyRatio && upperWick < bodySize * 0.5)
        {
         // Draw arrow below the low of the hammer
         HammerBuffer[i] = low[i] - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        }

      //--- Shooting Star Identification Logic ---
      // 1. Upper wick is long (at least WickToBodyRatio * bodySize)
      // 2. Lower wick is very small (less than half the body size)
      if(upperWick >= bodySize * WickToBodyRatio && lowerWick < bodySize * 0.5)
        {
         // Draw arrow above the high of the shooting star
         ShootingStarBuffer[i] = high[i] - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
        }
     }
   
   return(rates_total);
  }
//+------------------------------------------------------------------+