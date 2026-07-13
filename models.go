package main

import "time"

type LoginRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type User struct {
	ID       int    `json:"id"`
	Phone    string `json:"phone"`
	Fullname string `json:"fullname"`
	UserCode int    `json:"user_code"`
	Bin      string `json:"bin"`
}

type Device struct {
	ID           int     `json:"id"`
	Account      string  `json:"account"`
	UserCode     int     `json:"user_code"`
	DeviceName   string  `json:"device_name"`
	Type         int     `json:"type"`
	Bin          string  `json:"bin"`
	Group        string  `json:"gruppa"`
	DeviceStatus bool    `json:"device_status"`
	ServerStatus bool    `json:"server_status"`
	AbonTime     *string `json:"abon_time"`
	Summa        float64 `json:"summa"`
	SignalWiFi   string  `json:"signal_wifi"`
	Status       bool    `json:"status"`
	DataStatus   *string `json:"data_status"`
	DataInkas    *string `json:"data_inkas"`
}

type Money struct {
	ID        int       `json:"id"`
	Account   int       `json:"account"`
	PayMoney  int       `json:"pay_money"`
	CreatedAt time.Time `json:"created_at"`
}

type Coin struct {
	ID        int       `json:"id"`
	Account   int       `json:"account"`
	PayCoin   int       `json:"pay_coin"`
	CreatedAt time.Time `json:"created_at"`
}

type Payment struct {
	ID      int64      `json:"id"`
	TxnID   string     `json:"txn_id"`
	Account string     `json:"account"`
	Sum     float64    `json:"sum"`
	Result  int        `json:"result"`
	Comment string     `json:"comment"`
	Created *time.Time `json:"created"`
}
