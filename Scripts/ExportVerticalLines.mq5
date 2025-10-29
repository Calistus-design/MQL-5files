//+------------------------------------------------------------------+
//|                                        ExportVerticalLines.mq5 |
//|                                     Copyright 2023, Your Name |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name"
#property version   "1.00"
#property description "Scans all vertical lines on the chart and exports their datetimes to a text file."

//+------------------------------------------------------------------+
//| The main function where the script's logic begins.               |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- STEP 1: INITIALIZATION ---

   // Get the chart's identity to create a unique filename
   string symbol = _Symbol;
   string timeframe_str = PeriodToString(_Period);
   
   // Construct the unique filename
   string file_name = symbol + "_" + timeframe_str + "_Vertical_Lines.txt";
   
   // Open the file in 'write' mode (this will overwrite any existing file)
   int file_handle = FileOpen(file_name, FILE_WRITE | FILE_TXT);
   
   // Check if the file was opened successfully
   if(file_handle == INVALID_HANDLE)
     {
      MessageBox("Failed to create the output file. Error code: " + (string)GetLastError(), "File Error");
      return; // Stop the script if we can't create the file
     }

//--- STEP 2: THE SEARCH ---

   // A counter to keep track of how many lines we find
   int lines_found = 0;

   // Loop through every single object on the current chart
   for(int i = 0; i < ObjectsTotal(0); i++)
     {
      // Get the name of the object at the current position in the list
      string obj_name = ObjectName(0, i);
      
      // Check if this object's type is a vertical line (OBJ_VLINE)
      if(ObjectGetInteger(0, obj_name, OBJPROP_TYPE) == OBJ_VLINE)
        {
         //--- STEP 3: DATA EXTRACTION AND RECORDING ---
         
         // It is a vertical line, so get its time coordinate
         long line_time_long = ObjectGetInteger(0, obj_name, OBJPROP_TIME, 0);
         datetime line_time = (datetime)line_time_long;
         
         // Format the output string to be ONLY the date and time, as you requested
         string output_string = TimeToString(line_time, TIME_DATE | TIME_MINUTES);
         
         // Write the formatted string to our text file, followed by a new line
         FileWriteString(file_handle, output_string + "\r\n");
         
         // Increment our counter
         lines_found++;
        }
     }

//--- STEP 4: FINALIZATION ---

   // Close the file to save all changes
   FileClose(file_handle);
   
   // Prepare a final confirmation message for the user
   string final_message = StringFormat("Scan Complete.\n\nFound and exported %d vertical lines.\n\nData saved to MQL5\\Files\\%s", lines_found, file_name);
   
   // Display the message box
   MessageBox(final_message, "Export Successful");
  }

//+------------------------------------------------------------------+
//| A helper function to convert the timeframe into a readable string|
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return EnumToString(period);
     }
  }
//+------------------------------------------------------------------+