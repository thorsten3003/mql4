//+------------------------------------------------------------------+
//|                                                 Trade_Sender.mq4 |
//|                                                    Kenny Hubbard |
//|                                       http://www.compu-forex.com |
//+------------------------------------------------------------------+
 //mod. 2013 by fxdaytrader (//added)
#property copyright "Kenny Hubbard"
#property link      "http://www.compu-forex.com"

#define version "4b" //added
#define _SECONDS 1000

//fxdaytrader added
extern string     ith="******* Alert methods:";
extern bool       PopupNotifications   = true; 
extern bool       SendEmails           = false;
extern bool       SendPushNotification = true;
extern bool       PlaySounds           = false;
extern string     SoundFile            = "alert.wav";
extern string     ith1="******* misc settings:";
//end added
extern double     CalcLotDivisor       = 1.00;//Divebubble, added (may be used to hide the real lotsize if publishing via facebook, twitter & co.)
extern bool       Show_Screen_FeedBack = true;//false;
extern bool       Show_Account_Detail  = true;//false;
extern bool       Show_Equity          = true;//false;
extern bool       PrintStatusMessages  = true;//added fxdaytrader
extern bool       PopupAlertOnErrors   = true;//added fxdaytrader

extern string     Note1                = "----Trades to Show---";
extern bool       Show_Market          = true;
extern bool       Show_Pending         = true;
extern bool       Show_Executed_Pend   = true;
extern bool       Show_Modified        = true;
extern bool       Show_Closed          = true;
extern bool       Show_Deleted         = true;
extern bool       Expanded_Order_Info  = true;//false;
extern bool       Show_Trade_Result    = true;
extern bool       Show_Profit          = true;//false;
extern int        Mail_Retry           = 3;
extern int        Delay                = 4; //0; //Number of seconds to delay the sending to allow for stoploss inserting

int
   Order_State_Prev[][2],
   Order_State_New[][2],
   Pending_Order_State_Prev[][2],
   Pending_Order_State_New[][2],
   D_Factor = 1;
double
   Mod_State_Prev[][2],
   Mod_State_New[][2];   
bool 
   First_Run = true;
   
string
   Mail_Header,
   Extra_FeedBack = "";

//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
   /*
   if (Show_Account_Detail)Mail_Header = StringConcatenate(AccountCompany() , " Trade Alert : Acc No " , AccountNumber() , " " , AccountName());
    else Mail_Header = "OrderID #" + OrderTicket() + ": " + OrderSymbol();
   */
   if (!Show_Trade_Result)Show_Profit = false;
   Delay *= _SECONDS;
   if (PrintStatusMessages) Print("Init complete");
   return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   if (Show_Screen_FeedBack) Comment("");//added "if (Show_Screen_FeedBack)", fxdaytrader
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
double
   Order_Pips,
   My_Profit;
string
   Email_Text,
   Order_text;
int
   Order_Count,
   lmail_retry = Mail_Retry;
bool 
   Found_It = false;
//----
   if (!OrdersTotal()){
/*      if (First_Run){
         ArrayResize(Order_State_Prev,1);
         First_Run = false;
      }*/
      Extra_FeedBack = "No Orders Open at Present" + "\n";
   }
   Order_Count = Pending_Count();                                    // count the number of pending orders
   ArrayResize(Pending_Order_State_New,MathMax(Order_Count,1));      // make the fresh order array the same size as the number of pending orders
   ArrayResize(Order_State_New,MathMax(OrdersTotal(),1));            // make the order array the same size as the number of orders
   ArrayResize(Mod_State_New,MathMax(OrdersTotal(),1));
//=============================================================== load the array with the order details   
   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
         Order_State_New[i][0] = OrderType();
         Order_State_New[i][1] = OrderTicket();
         Mod_State_New[i][0] = OrderStopLoss();
         Mod_State_New[i][1] = OrderTakeProfit();
         if(OrderType()<2)continue;//not a pending order so move on
         if(OrderType()>5)continue;//not a pending order so move on(covers apparently undocumented ordertypes with val >5)
         Pending_Order_State_New[i][0] = OrderType();
         Pending_Order_State_New[i][1] = OrderTicket();
      }
   }
//=============================================================== check if this is the first run of the EA   
   if(First_Run){   
      ArrayResize(Order_State_Prev,MathMax(ArraySize(Order_State_New)/2,1));
      ArrayCopy(Order_State_Prev,Order_State_New,0,0,WHOLE_ARRAY);//copy the array for next tick comparison
      ArrayResize(Mod_State_Prev,MathMax(ArraySize(Mod_State_New)/2,1));
      ArrayCopy(Mod_State_Prev,Mod_State_New,0,0,WHOLE_ARRAY);//copy the array for next tick comparison
      ArrayResize(Pending_Order_State_Prev,MathMax(ArraySize(Pending_Order_State_New)/2,1));
      ArrayCopy(Pending_Order_State_Prev,Pending_Order_State_New,0,0,WHOLE_ARRAY);
      First_Run = false;                                          //first run is done, so set flag false for the future
      return(0);
   }
//=============================================================== the arrays are loaded now we can compare to find changes   
   if (Show_Executed_Pend)Pending_Taken_Detect(Order_Count);      //check pending orders first........separate routine
   if (Show_Modified){
      for(i=0;i<OrdersTotal();i++){
         if(OrderSelect(i, SELECT_BY_POS)){
            if(OrderTicket() == Order_State_Prev[i][1]){
               if(OrderStopLoss() != Mod_State_Prev[i][0]||OrderTakeProfit() != Mod_State_Prev[i][1]){
                  Order_Modify_Email(OrderTicket(),OrderSymbol(),Mod_State_New[i][0], Mod_State_New[i][1],OrderLots() / CalcLotDivisor,OrderOpenPrice());
               }
            }
         }
      }
   }     
   ArrayResize(Mod_State_Prev,MathMax(ArraySize(Mod_State_New)/2,1));
   ArrayCopy(Mod_State_Prev,Mod_State_New,0,0,WHOLE_ARRAY); 
   if (OrdersTotal() == ArraySize(Order_State_Prev)/2){
      if (Show_Screen_FeedBack)User_FeedBack(Extra_FeedBack);
      if (StringLen(Extra_FeedBack) > 500)Extra_FeedBack = "";
      return(0);     //nothing has changed so move back to the beginning
   }
//***************************************************************

//+----------------------------------------------------------------------------------------------------------+
//|At this point there is a change in the new array compared to the previous array.........we have 2 options |                                                                |
//+----------------------------------------------------------------------------------------------------------+


//****************** OPTION 1 New Order Added *******************
//===============================================================
   if (OrdersTotal() > ArraySize(Order_State_Prev)/2){           //more orders than before....lets search the open order tickets and compare with old tickets
      for(i=0;i<OrdersTotal();i++){
         OrderSelect(i,SELECT_BY_POS,MODE_TRADES);
         for(int i_2=0;i_2<ArraySize(Order_State_Prev)/2;i_2++){
            if(OrderTicket() == Order_State_Prev[i_2][1]){
               Found_It = true;
               break;
            }
         }
         int ticket = OrderTicket();
         if (!Found_It){
            Email_Text = Get_Order_Text(OrderType()) + " " + DoubleToStr(OrderLots() / CalcLotDivisor,2) + " @ " + DoubleToStr(OrderOpenPrice(),Digits);
            if (Delay > 0){
               if (OrderStopLoss() == 0 ||OrderTakeProfit() == 0){
                  Sleep(Delay);
                  OrderSelect(OrderTicket(),SELECT_BY_TICKET);
                  if (OrderStopLoss() != 0 ||OrderTakeProfit() != 0)Email_Text = Email_Text + ", SL " + DoubleToStr(OrderStopLoss(),Digits) + ", TP " + DoubleToStr(OrderTakeProfit(),Digits); 
               }
            }
            else Email_Text = Email_Text + ", SL " + DoubleToStr(OrderStopLoss(),Digits) + ", TP " + DoubleToStr(OrderTakeProfit(),Digits);
            if (Expanded_Order_Info)Email_Text = Email_Text + " @ " + TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES); 
            Mail_Header = "ID" + OrderTicket() + ": " + OrderSymbol(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
             if (Show_Market && OrderType() <= 1) doSendNotifications(Mail_Header, Email_Text);//other notifications, added, fxdaytrader
             if (Show_Pending && OrderType() >= 2 && OrderType() <= 5) doSendNotifications(Mail_Header, Email_Text);//other notifications, added, fxdaytrader
            while (lmail_retry > 0){                       
               if (Show_Market && OrderType() <= 1) DoSendMail(Mail_Header, Email_Text);
               if (Show_Pending && OrderType() >= 2 && OrderType() <= 5) DoSendMail(Mail_Header, Email_Text);
               if(GetLastError() == 4061)Mail_Retry--;
               else break;
            }//while
            if (PrintStatusMessages) Print(Mail_Header, Email_Text);
            if (GetLastError() == 4061 && PopupAlertOnErrors) Alert("Error Sending Email, please check your settings and service provider");
            else{
               Extra_FeedBack = StringConcatenate(Extra_FeedBack, " New Order Ticket #", OrderTicket(), " email sent.\n");
               if (Show_Screen_FeedBack)User_FeedBack(Extra_FeedBack);
            }//else
         }//if(Found_it)
         Found_It = false;
      }//for(i=0;i<OrdersTotal();i++){
   }
   
//************ OPTION 2 An Order is closed or deleted *****************
//=====================================================================
   if (OrdersTotal() < ArraySize(Order_State_Prev)/2){           //fewer orders than before....lets search the closed order tickets and compare with old tickets
      for(i=0;i<OrdersHistoryTotal();i++){
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
            if (MarketInfo(OrderSymbol(),MODE_DIGITS) == 3|| MarketInfo(OrderSymbol(),MODE_DIGITS) == 5)D_Factor = 10;
            else D_Factor = 1;
            for(i_2=0;i_2<ArraySize(Order_State_Prev)/2;i_2++){
               if(OrderTicket() != Order_State_Prev[i_2][1])continue;
               else{
                  switch(OrderType()){
                     case OP_BUY  : Order_Pips = (OrderClosePrice() - OrderOpenPrice())/MarketInfo(OrderSymbol(),MODE_POINT)/D_Factor;
                                    Email_Text = StringConcatenate("Buy Closed ", DoubleToStr(OrderLots()  / CalcLotDivisor,2), " @ ", DoubleToStr(OrderClosePrice(), Digits));
                                    Mail_Header = OrderSymbol()+" ID " + OrderTicket(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
                                    break;
                     case OP_SELL : Order_Pips = (OrderOpenPrice() - OrderClosePrice())/MarketInfo(OrderSymbol(),MODE_POINT)/D_Factor;
                                    Email_Text = StringConcatenate("Sell Closed ", DoubleToStr(OrderLots()  / CalcLotDivisor,2), " @ ", DoubleToStr(OrderClosePrice(), Digits));
                                    Mail_Header = OrderSymbol()+" ID " + OrderTicket(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
                                    break;
                     default      : Email_Text = StringConcatenate(Get_Order_Text(OrderType()), " ", DoubleToStr(OrderLots() / CalcLotDivisor,2), " deleted");
                                    Mail_Header = OrderSymbol()+" ID " + OrderTicket(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
                                    break;
                  }//switch
                  if (Expanded_Order_Info)Email_Text = Email_Text + " @ " + TimeToStr(OrderOpenTime(),TIME_DATE|TIME_MINUTES);
                  if (Show_Trade_Result && OrderType() <= 1)Email_Text = Email_Text + ", " + DoubleToStr(Order_Pips * 0.1,1) + " Pips";
                  if (Show_Profit && OrderType() <= 1){
                     My_Profit = OrderProfit() + OrderCommission() + OrderSwap();//OrderProfit() - OrderCommission() - OrderSwap(); //fxdaytrader, added corrected
                     Email_Text = "\n" + Email_Text + " Net Profit/Loss = " + AccountCurrency() + " " + DoubleToStr(My_Profit,2);
                  }
                  //if (Show_Equity)Email_Text = "\n" + Email_Text + "\n" + "Your Balance is " + DoubleToStr(AccountBalance(),2) + "/Equity " + DoubleToStr(AccountEquity(),2);
                  if (Show_Equity)Email_Text = "\n" + Email_Text + "\n" + "Your Balance is " + DoubleToStr(AccountBalance(),2) + " "+AccountCurrency()+" /Equity " + DoubleToStr(AccountEquity(),2)+" "+AccountCurrency();//fxdaytrader, currency-info added
                 
                  if (Show_Closed && OrderType() <= 1) doSendNotifications(Mail_Header, Email_Text);//other notifications, added, fxdaytrader
                  if (Show_Deleted && OrderType() >= 2 && OrderType() <= 5) doSendNotifications(Mail_Header, Email_Text);//other notifications, added, fxdaytrader
                  while (lmail_retry > 0){
                     if (Show_Closed && OrderType() <= 1) DoSendMail(Mail_Header, Email_Text);
                     if (Show_Deleted && OrderType() >= 2 && OrderType() <= 5) DoSendMail(Mail_Header, Email_Text);
                     if(GetLastError() == 4061)Mail_Retry--;
                     else break;
                  }
                  if (GetLastError() == 4061 && PopupAlertOnErrors) Alert("Error Sending Email, please check your settings and service provider");
                  else{
                     Extra_FeedBack = StringConcatenate(Extra_FeedBack, "Closed or Deleted Ticket #", OrderTicket(), " email sent.\n");
                     if (Show_Screen_FeedBack)User_FeedBack(Extra_FeedBack);
                  }
                  if (PrintStatusMessages) Print(Mail_Header, Email_Text);
                  break;
               }//else
            }//for(i_2=0;i_2<ArraySize(Order_State_Prev)/2;i_2++){
         }//if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){
      }//for(i=0;i<OrdersHistoryTotal();i++){
   }
   ArrayResize(Order_State_Prev,MathMax(OrdersTotal(),0));
   if (OrdersTotal() == 0)return(0);
   ArrayCopy(Order_State_Prev,Order_State_New,0,0,WHOLE_ARRAY);//copy the array for future comparison
//----
   return(0);
}
//+------------------------------------------------------------------+
string Get_Order_Text(int lOrdertype)
{
   switch (lOrdertype){
      case OP_BUY       :return(" Buy");
      case OP_SELL      :return(" Sell");
      case OP_BUYLIMIT  :return(" Buy Limit");
      case OP_BUYSTOP   :return(" Buy Stop");
      case OP_SELLLIMIT :return(" Sell Limit");
      case OP_SELLSTOP  :return(" Sell Stop");
      default           :return(" Unidentified");
   }
}
//+------------------------------------------------------------------+
string Bool_to_Text(int lbool)
{
   if (lbool == true)return("True");
   else return("False");
}
//+------------------------------------------------------------------+
void User_FeedBack(string l_extra_text)
{
int
   lDelay = Delay/_SECONDS;
string
   cmt = "Trade Sender Information" + "\n";
   cmt = cmt + "------------------------------------" + "\n";
   cmt = cmt + "Show_Account_Detail = " +  Bool_to_Text(Show_Account_Detail) + "\n";
   cmt = cmt + "Show_Equity             = " +  Bool_to_Text(Show_Equity) + "\n";
   cmt = cmt + "Show_Market            = " +  Bool_to_Text(Show_Market) + "\n";
   cmt = cmt + "Show_Pending          = " +  Bool_to_Text(Show_Pending) + "\n";
   cmt = cmt + "Show_Closed           = " +  Bool_to_Text(Show_Closed) + "\n";
   cmt = cmt + "Show_Deleted          = " +  Bool_to_Text(Show_Deleted) + "\n";
   cmt = cmt + "Expanded_Order_Info   = " +  Bool_to_Text(Expanded_Order_Info) + "\n";
   cmt = cmt + "Show_Trade_Result   = " +  Bool_to_Text(Show_Trade_Result) + "\n";
   cmt = cmt + "Show_Profit             = " +  Bool_to_Text(Show_Profit) + "\n";
   cmt = cmt + "SL/TP Delay             = " +  lDelay + " Seconds" + "\n";
   cmt = cmt + "------------------------------------" + "\n";
   cmt = cmt + l_extra_text + "\n";
   Comment(cmt);
}
//+------------------------------------------------------------------+
void Pending_Taken_Detect(int lnum_pendings)
{
bool
   Pend_Found_It = false;
//----
   if (lnum_pendings == ArraySize(Pending_Order_State_Prev)/2)return;//if num pending orders is unchanged since last tick>>nothing has changed>>copy array and move on
   for(int i=0;i<OrdersTotal();i++){//num pending orders is less>>>search open orders for known previous pending order ticket no
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
         if(OrderType()<= 1){
            for(int i_2=0;i_2<ArraySize(Pending_Order_State_Prev)/2;i_2++){
               if(OrderTicket()== Pending_Order_State_Prev[i_2][1]){
                  Pend_Found_It = true;
                  break;
               }
            }
         }
      }
      if(Pend_Found_It){
         //string Pending_Email_Text = "Pending Activated @ " + DoubleToStr(OrderOpenPrice(),Digits);
         string Pending_Email_Text = "Pending Order Activated:"+Get_Order_Text(OrderType())+" @ " + DoubleToStr(OrderOpenPrice(),Digits);//fxdaytrader, added ordertype
         Mail_Header = OrderSymbol()+" ID " + OrderTicket(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
         if (Expanded_Order_Info)Pending_Email_Text = Pending_Email_Text + " @ " + TimeToStr(TimeCurrent(),TIME_DATE|TIME_MINUTES);
         doSendNotifications(Mail_Header, Pending_Email_Text);
         Extra_FeedBack = Extra_FeedBack + " Pending Order Activated : Ticket #" + OrderTicket() + " email sent.\n";
         if (Show_Screen_FeedBack)User_FeedBack(Extra_FeedBack);
         Pend_Found_It = false;
         if (PrintStatusMessages) Print(Mail_Header, Pending_Email_Text);
         break;
      }
   }
   ArrayResize(Pending_Order_State_Prev,MathMax(ArraySize(Pending_Order_State_New)/2,0));//======copy fresh array to prev order array and wait for new tick
   if (OrdersTotal() == 0)return(0);
   ArrayCopy(Pending_Order_State_Prev,Pending_Order_State_New,0,0,WHOLE_ARRAY);
   return(0);
}
//+------------------------------------------------------------------+
int Pending_Count()//counts the number of current pending orders>>dynamic array sizing
{
int cnt = 0;
   for(int i=0;i<=OrdersTotal()-1;i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
            if(OrderType()<2)continue;//not a pending order so move on
            if(OrderType()>5)continue;//not a pending order so move on(covers apparently undocumented ordertypes with val >5)
            cnt++;
      }
   }
   return(cnt);
}
//+------------------------------------------------------------------+
void Order_Modify_Email(int lticket, string lMy_Symbol, double lNew_SL, double lNew_TP, double lLots, double lOpenPrice)
{
int
   My_Digits = MarketInfo(lMy_Symbol,MODE_DIGITS);
string
   Mod_Text = StringConcatenate("Modified, SL ", DoubleToStr(lNew_SL, My_Digits),
                                ", TP ", DoubleToStr(lNew_TP, My_Digits), ", " , DoubleToStr(lLots,2), " @ ", DoubleToStr(lOpenPrice,My_Digits));
   Mail_Header = OrderSymbol()+" ID " + OrderTicket(); //fxdaytrader, changed from: StringSubstr(OrderSymbol(),0,5);
   doSendNotifications(Mail_Header, Mod_Text);
   if (PrintStatusMessages) Print(Mod_Text);
   Extra_FeedBack = StringConcatenate(Extra_FeedBack, "Order Modified Ticket ", lticket, " email sent.\n");
   if (Show_Screen_FeedBack)User_FeedBack(Extra_FeedBack);
}
//+------------------------------------------------------------------+


void DoSendMail(string cHeader, string cText) {
 while (IsTradeContextBusy()) Sleep(100); //fxdaytrader
 if (SendEmails) SendMail(cHeader, cText);//"if (SendEmails) " added, fxdaytrader
}

void doSendNotifications(string header,string text) { //added fxdaytrader
 while (IsTradeContextBusy()) Sleep(100); //fxdaytrader
 if (PopupNotifications) Alert(text+" - "+header);
 //if (SendEmails) SendMail(header,text);
 if (PlaySounds) PlaySound(SoundFile);
 if (SendPushNotification) SendNotification(text+" - "+header);
}