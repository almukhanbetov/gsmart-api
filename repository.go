package main
import "context"
func findUserByPhone(
	ctx context.Context,
	phone string,
) (User, string, error) {
	var user User
	var passwordHash string
	query := `
		SELECT
			id,
			phone,
			fullname,
			password_hash,
			user_code,
			bin
		FROM users
		WHERE phone = $1
	`

	err := db.QueryRow(
		ctx,
		query,
		phone,
	).Scan(
		&user.ID,
		&user.Phone,
		&user.Fullname,
		&passwordHash,
		&user.UserCode,
		&user.Bin,
	)

	return user, passwordHash, err
}

func getDevices(
	ctx context.Context,
	userCode int,
) ([]Device, error) {
	query := `
		SELECT
			id,
			account,
			user_code,
			COALESCE(device_name, ''),
			type,
			COALESCE(bin, ''),
			COALESCE(gruppa, ''),
			COALESCE("DeviceStatus", false),
			COALESCE("ServerStatus", false),
			abon_time::text,
			COALESCE(summa, 0),
			COALESCE(signal_wifi, ''),
			COALESCE(status, false),
			data_status::text,
			data_inkas::text
		FROM devices
		WHERE user_code = $1
		ORDER BY id
	`

	rows, err := db.Query(ctx, query, userCode)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	devices := make([]Device, 0)

	for rows.Next() {
		var device Device

		err := rows.Scan(
			&device.ID,
			&device.Account,
			&device.UserCode,
			&device.DeviceName,
			&device.Type,
			&device.Bin,
			&device.Group,
			&device.DeviceStatus,
			&device.ServerStatus,
			&device.AbonTime,
			&device.Summa,
			&device.SignalWiFi,
			&device.Status,
			&device.DataStatus,
			&device.DataInkas,
		)
		if err != nil {
			return nil, err
		}

		devices = append(devices, device)
	}

	return devices, rows.Err()
}
func getMoney(
	ctx context.Context,
	userCode int,
) ([]Money, error) {
	query := `
		SELECT
			m.id,
			m.account,
			m.pay_money,
			m.created_at
		FROM money m
		INNER JOIN devices d
			ON d.account = m.account::text
		WHERE d.user_code = $1
		ORDER BY m.created_at DESC
	`

	rows, err := db.Query(ctx, query, userCode)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Money, 0)

	for rows.Next() {
		var item Money

		err := rows.Scan(
			&item.ID,
			&item.Account,
			&item.PayMoney,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}

func getMoneyByAccount(
	ctx context.Context,
	account int,
) ([]Money, error) {
	query := `
		SELECT
			id,
			account,
			pay_money,
			created_at
		FROM money
		WHERE account = $1
		ORDER BY created_at DESC
	`

	rows, err := db.Query(ctx, query, account)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Money, 0)

	for rows.Next() {
		var item Money

		err := rows.Scan(
			&item.ID,
			&item.Account,
			&item.PayMoney,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}

func getCoinsByAccount(
	ctx context.Context,
	account int,
) ([]Coin, error) {
	query := `
		SELECT
			id,
			account,
			pay_coin,
			created_at
		FROM coin
		WHERE account = $1
		ORDER BY created_at DESC
	`

	rows, err := db.Query(ctx, query, account)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Coin, 0)

	for rows.Next() {
		var item Coin

		err := rows.Scan(
			&item.ID,
			&item.Account,
			&item.PayCoin,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}

func getPaymentsByAccount(
	ctx context.Context,
	account string,
) ([]Payment, error) {
	query := `
		SELECT
			id,
			txn_id,
			account,
			COALESCE(sum, 0),
			COALESCE(result, 0),
			COALESCE(comment, ''),
			created
		FROM payments
		WHERE account = $1
		ORDER BY created DESC NULLS LAST
	`

	rows, err := db.Query(ctx, query, account)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Payment, 0)

	for rows.Next() {
		var item Payment

		err := rows.Scan(
			&item.ID,
			&item.TxnID,
			&item.Account,
			&item.Sum,
			&item.Result,
			&item.Comment,
			&item.Created,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}

func getCoins(
	ctx context.Context,
	userCode int,
) ([]Coin, error) {
	query := `
		SELECT
			c.id,
			c.account,
			c.pay_coin,
			c.created_at
		FROM coin c
		INNER JOIN devices d
			ON d.account = c.account::text
		WHERE d.user_code = $1
		ORDER BY c.created_at DESC
	`

	rows, err := db.Query(ctx, query, userCode)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Coin, 0)

	for rows.Next() {
		var item Coin

		err := rows.Scan(
			&item.ID,
			&item.Account,
			&item.PayCoin,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}

func getPayments(
	ctx context.Context,
	userCode int,
) ([]Payment, error) {
	query := `
		SELECT
			p.id,
			p.txn_id,
			p.account,
			COALESCE(p.sum, 0),
			COALESCE(p.result, 0),
			COALESCE(p.comment, ''),
			p.created
		FROM payments p
		INNER JOIN devices d
			ON d.account = p.account
		WHERE d.user_code = $1
		ORDER BY p.created DESC NULLS LAST
	`

	rows, err := db.Query(ctx, query, userCode)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make([]Payment, 0)

	for rows.Next() {
		var item Payment

		err := rows.Scan(
			&item.ID,
			&item.TxnID,
			&item.Account,
			&item.Sum,
			&item.Result,
			&item.Comment,
			&item.Created,
		)
		if err != nil {
			return nil, err
		}

		result = append(result, item)
	}

	return result, rows.Err()
}
