//+------------------------------------------------------------------+
//|                                      OuterResistanceSignal.mq5 |
//|                                                      Copyright 2025 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.50" // Updated with Major Outer Resistance Filter
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- plot BearishArrow
#property indicator_label1  "BearishArrow"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMagenta // Changed color to signify major update
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator Inputs ---
// NEW INPUTS for the Macro Filter
input int MajorResistanceLookback = 200; // Lookback period to find the Major High
input int MajorZonePoints = 300;         // How many points below the Major High is considered the "Outer Area"

// Existing Inputs for the Micro Filter
input int PivotLookback = 50;   // (Renamed from ResistanceLookback for clarity) Max candles to look back for the local pivot match
input int PointTolerance = 3;   // Tolerance for matching the exact pivot level

//--- indicator buffers
double         BearishBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0, BearishBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_ARROW, 234); 
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Ensure we have enough bars for our largest lookback
   if(rates_total < MajorResistanceLookback) return(0);
   
   // Start calculation from a safe index
   int start_i = prev_calculated > MajorResistanceLookback ? prev_calculated - 1 : MajorResistanceLookback;

//--- main loop
   for(int i = start_i; i < rates_total; i++)
     {
      BearishBuffer[i] = 0.0;
      
      //====================================================================
      // FILTER 1 (NEW): MACRO LOCATION CHECK - Are we at Outer Resistance?
      //====================================================================
      double majorHigh = 0;
      // Find the highest high in the last 'MajorResistanceLookback' candles
      for(int m = i - 1; m > i - MajorResistanceLookback && m >= 0; m--)
        {
         if(high[m] > majorHigh) majorHigh = high[m];
        }
      
      // Define the bottom of the "Outer Resistance Area"
      double zoneBottom = majorHigh - (MajorZonePoints * _Point);
      
      // If the high of our setup candle [i-1] is below this zone, it's not at outer resistance.
      // Skip it.
      if(high[i-1] < zoneBottom) 
        {
         continue;
        }

      //====================================================================
      // If we passed Filter 1, proceed with the existing logic...
      //====================================================================
      
      //--- FILTER 2: PATTERN IDENTIFICATION ---
      bool isLastCandleGreen = (close[i-1] > open[i-1]);
      if(!isLastCandleGreen) continue;

      bool is_i_minus_2_Red = (close[i-2] < open[i-2]);
      bool is_i_minus_3_Red = (close[i-3] < open[i-3]);
      bool is_i_minus_4_Red = (close[i-4] < open[i-4]);
      bool is_i_minus_5_Red = (close[i-5] < open[i-5]);

      bool is_RG_Pattern = is_i_minus_2_Red && !is_i_minus_3_Red;
      bool is_RRG_Pattern = is_i_minus_2_Red && is_i_minus_3_Red && !is_i_minus_4_Red;
      bool is_RRRG_Pattern = is_i_minus_2_Red && is_i_minus_3_Red && is_i_minus_4_Red && !is_i_minus_5_Red;

      if(is_RG_Pattern || is_RRG_Pattern || is_RRRG_Pattern)
        {
         //--- FILTER 3: BODY SIZE COMPARISON ---
         if(MathAbs(close[i-1] - open[i-1]) < MathAbs(close[i-2] - open[i-2]))
           {
            //--- FILTER 4: EXACT LOCAL PIVOT LEVEL CHECK ---
            bool resistanceLevelMatch = false;
            double greenCandleClose = close[i-1];
            double tolerance = PointTolerance * _Point; 

            // Loop backwards to find a local resistance pivot
            for(int k = i - 5; k > i - PivotLookback && k > 0; k--)
              {
               // A resistance pivot is a Green candle followed by a Red candle
               if(close[k] > open[k] && close[k+1] < open[k+1])
                 {
                  // The EXACT level is the close of the green pivot candle
                  double resistanceLevel = close[k];

                  // Check if our green candle closed AT this exact level (within tolerance)
                  if(MathAbs(greenCandleClose - resistanceLevel) <= tolerance)
                    {
                     resistanceLevelMatch = true; 
                     break; 
                    }
                 }
              }

            if(resistanceLevelMatch)
              {
               // If ALL 4 filters pass, draw the arrow
               BearishBuffer[i] = high[i-1] + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15);
              }
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+