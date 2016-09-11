
#define FONT "Arial"
   
#define m5Color Green
#define m4Color Green
#define m3Color Green
#define m2Color Red
#define m1Color Red
#define m0Color Red

#property indicator_chart_window 
#property indicator_buffers 7
#property indicator_color1 m0Color
#property indicator_color2 m1Color
#property indicator_color3 m2Color
#property indicator_color4 m3Color
#property indicator_color5 m4Color
#property indicator_color6 m5Color

extern string version = "2.0"; 

extern string note="Pls make sure the same as Pivot Points indicator";
extern int ShiftHrs = 0;                          
extern bool useDaily=true;
extern bool useWeekly=false;
extern bool useMonthly=false;
extern bool use_m0=true;
extern bool use_m1=true;
extern bool use_m2=true;
extern bool use_m3=true;
extern bool use_m4=true;
extern bool use_m5=true;

double m0_buffer[], m1_buffer[], m2_buffer[], m3_buffer[], m4_buffer[], m5_buffer[];

string m0_name, m1_name,m2_name,m3_name,m4_name,m5_name; 
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   SetIndexBuffer( 0, m0_buffer);
   SetIndexBuffer( 1, m1_buffer);
   SetIndexBuffer( 2, m2_buffer);
   SetIndexBuffer( 3, m3_buffer);
   SetIndexBuffer( 4, m4_buffer);
   SetIndexBuffer( 5, m5_buffer);

   // Set styles
   SetIndexStyle( 0, DRAW_LINE, STYLE_DASH, 1);
   SetIndexStyle( 1, DRAW_LINE, STYLE_DASH, 1);
   SetIndexStyle( 2, DRAW_LINE, STYLE_DASH, 1);
   SetIndexStyle( 3, DRAW_LINE, STYLE_DASH, 1);
   SetIndexStyle( 4, DRAW_LINE, STYLE_DASH, 1);
   SetIndexStyle( 5, DRAW_LINE, STYLE_DASH, 1);

   // Set empty values
   SetIndexEmptyValue( 0, EMPTY_VALUE );
   SetIndexEmptyValue( 1, EMPTY_VALUE );
   SetIndexEmptyValue( 2, EMPTY_VALUE );
   SetIndexEmptyValue( 3, EMPTY_VALUE );
   SetIndexEmptyValue( 4, EMPTY_VALUE );
   SetIndexEmptyValue( 5, EMPTY_VALUE );

   m0_name="m0";
   m1_name="m1";
   m2_name="m2";
   m3_name="m3";
   m4_name="m4";
   m5_name="m5";
   
   // Set labels
   SetIndexLabel( 0, m0_name );
   SetIndexLabel( 1, m1_name );
   SetIndexLabel( 2, m2_name );
   SetIndexLabel( 3, m3_name );
   SetIndexLabel( 4, m4_name );
   SetIndexLabel( 5, m5_name );
   
   // Put text on the chart
   ObjectCreate( m0_name, OBJ_TEXT, 0, 0, 0 );
   ObjectCreate( m1_name, OBJ_TEXT, 0, 0, 0 );
   ObjectCreate( m2_name, OBJ_TEXT, 0, 0, 0 );
   ObjectCreate( m3_name, OBJ_TEXT, 0, 0, 0 );
   ObjectCreate( m4_name, OBJ_TEXT, 0, 0, 0 );
   ObjectCreate( m5_name, OBJ_TEXT, 0, 0, 0 );

   // Set the text characteristics
   ObjectSetText( m0_name, m0_name, 8, FONT, Red );
   ObjectSetText( m1_name, m1_name, 8, FONT, Red );
   ObjectSetText( m2_name, m2_name, 8, FONT, Red );
   ObjectSetText( m3_name, m3_name, 8, FONT, Green );
   ObjectSetText( m4_name, m4_name, 8, FONT, Green );
   ObjectSetText( m5_name, m5_name, 8, FONT, Green );

//---- indicators
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   ObjectDelete( m0_name );
   ObjectDelete( m1_name );
   ObjectDelete( m2_name );
   ObjectDelete( m3_name );
   ObjectDelete( m4_name );
   ObjectDelete( m5_name );
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int limit;
   int counted_bars=IndicatorCounted();
//---- last counted bar will be recounted
   if(counted_bars>0) counted_bars--;
   limit=Bars-counted_bars;
//---- macd counted in the 1-st buffer

   for(int i=0; i<limit; i++)
   {
      double r3=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,0,i); 
      double r2=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,1,i);
      double r1=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,2,i);
      double pp=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,3,i);
      double s1=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,4,i);
      double s2=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,5,i);
      double s3=iCustom(NULL,0,"Pivot Points ",version,ShiftHrs, useDaily, useWeekly, useMonthly,6,i);
      
      //Print("r3" + r3); 
      
      if(use_m5==true) m5_buffer[i] = (r2 + r3)/2;
      if(use_m4==true) m4_buffer[i] =(r1 + r2)/2;
      if(use_m3==true) m3_buffer[i]=(pp + r1)/2;
      if(use_m2==true) m2_buffer[i] =(pp + s1)/2;
      if(use_m1==true) m1_buffer[i] =(s1 + s2)/2;
      if(use_m0==true) m0_buffer[i] = (s2 + s3)/2;   
      
      ObjectMove( m0_name, 0, Time[0], m0_buffer[i] );
      ObjectMove( m1_name, 0, Time[0], m1_buffer[i] );
      ObjectMove( m2_name, 0, Time[0], m2_buffer[i] );
      ObjectMove( m3_name, 0, Time[0], m3_buffer[i] );
      ObjectMove( m4_name, 0, Time[0], m4_buffer[i] );
      ObjectMove( m5_name, 0, Time[0], m5_buffer[i] );
   }      
     
               
   //double s3=iCustom(NULL,0,"Pivot Points ",version, ShiftHrs, useDaily, useWeekly, useMonthly,6,1); 

//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+