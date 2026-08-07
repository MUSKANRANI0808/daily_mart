<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Access-Control-Allow-Methods: *");
header("Content-Type: application/json");

ini_set('display_errors', 0);
error_reporting(E_ALL);

date_default_timezone_set('Asia/Kolkata');

$host = "localhost";
$user = "daily_mart";
$pass = "DWZYHcAxSars3di8";
$dbname = "daily_mart";

$conn = @new mysqli($host, $user, $pass, $dbname);

if ($conn->connect_error) {
    echo json_encode(["success" => false, "error" => "DB Connection Failed"]);
    exit();
}

$action = isset($_GET['action']) ? $_GET['action'] : '';
$rawInput = @file_get_contents('php://input');
$input = json_decode($rawInput, true);
if (!is_array($input)) $input = array();

// 1. Auto-check & create address_json column in customers table if missing
$colCheckAddr = $conn->query("SHOW COLUMNS FROM customers LIKE 'address_json'");
if (!$colCheckAddr || $colCheckAddr->num_rows == 0) {
    @$conn->query("ALTER TABLE customers ADD COLUMN address_json LONGTEXT DEFAULT NULL");
}

// 2. Auto-check & create payment & order columns in messages table if missing
$colCheckPay = $conn->query("SHOW COLUMNS FROM messages LIKE 'payment_status'");
if (!$colCheckPay || $colCheckPay->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN payment_status VARCHAR(20) DEFAULT 'unpaid', ADD COLUMN payment_utr VARCHAR(100) DEFAULT NULL, ADD COLUMN paid_amount DECIMAL(10,2) DEFAULT 0.00, ADD COLUMN paid_at VARCHAR(50) DEFAULT NULL");
}

$colCheckAmt = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
if (!$colCheckAmt || $colCheckAmt->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT 0.00");
}

$colCheckBill = $conn->query("SHOW COLUMNS FROM messages LIKE 'bill_image'");
if (!$colCheckBill || $colCheckBill->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN bill_image LONGTEXT DEFAULT NULL");
}

// 3. Auto-check & create seller_products table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    unit VARCHAR(50) NOT NULL DEFAULT 'Pcs',
    qty INT NOT NULL DEFAULT 1,
    rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckQty = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'qty'");
if (!$colCheckQty || $colCheckQty->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN qty INT NOT NULL DEFAULT 1");
}

// 4. Auto-check & create seller_units table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_units (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

if ($action == 'customer-login') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $address_json = isset($input['address_json']) ? (is_array($input['address_json']) ? json_encode($input['address_json']) : trim($input['address_json'])) : '';

    $cName = 'Customer';
    $cAddr = '';

    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
        $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

        // 1. Check existing name & address from customers table
        $chkRes = $conn->query("SELECT name, address_json FROM customers WHERE mobile = '$mobile' OR mobile LIKE '$escapedLike' ORDER BY id DESC LIMIT 1");
        if ($chkRes && $chkRow = $chkRes->fetch_assoc()) {
            $exName = trim($chkRow['name'] ?? '');
            if (!empty($exName) && $exName !== 'Customer' && strpos($exName, 'Customer') !== 0) {
                $cName = $exName;
            }
            if (!empty($chkRow['address_json'])) {
                $cAddr = $chkRow['address_json'];
            }
        }

        // 2. If new valid name or address passed, update database
        if (!empty($name) && $name !== 'Customer' && strpos($name, 'Customer') !== 0) {
            $cName = $name;
        }
        if (!empty($address_json)) {
            $cAddr = $address_json;
        }

        if (!empty($cName) || !empty($cAddr)) {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name, address_json) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("sss", $mobile, $cName, $cAddr);
                $stmt->execute();
            }
        }
    }
    echo json_encode(["success" => true, "role" => "customer", "mobile" => $mobile, "name" => $cName, "address_json" => $cAddr]);
    exit();
} elseif ($action == 'get-customer-profile') {
    $mobile = isset($_GET['mobile']) ? trim($_GET['mobile']) : (isset($input['mobile']) ? trim($input['mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $cName = 'Customer';
    $cAddr = '';
    if (!empty($last10)) {
        $res = $conn->query("SELECT name, address_json FROM customers WHERE mobile = '$mobile' OR mobile LIKE '$escapedLike' ORDER BY id DESC LIMIT 1");
        if ($res && $row = $res->fetch_assoc()) {
            $dbName = trim($row['name'] ?? '');
            if (!empty($dbName)) $cName = $dbName;
            if (!empty($row['address_json'])) $cAddr = $row['address_json'];
        }
    }
    echo json_encode(["success" => true, "mobile" => $mobile, "name" => $cName, "address_json" => $cAddr]);
    exit();
} elseif ($action == 'update-customer-profile' || $action == 'save-customer-address') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $address_json = isset($input['address_json']) ? (is_array($input['address_json']) ? json_encode($input['address_json']) : trim($input['address_json'])) : '';

    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

        if (!empty($address_json) && !empty($name) && $name !== 'Customer') {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name, address_json) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("sss", $mobile, $name, $address_json);
                $stmt->execute();
            }
        } elseif (!empty($address_json)) {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, address_json) VALUES (?, ?) ON DUPLICATE KEY UPDATE address_json = VALUES(address_json)");
            if ($stmt) {
                $stmt->bind_param("ss", $mobile, $address_json);
                $stmt->execute();
            }
        } elseif (!empty($name) && $name !== 'Customer') {
            $stmt = $conn->prepare("INSERT INTO customers (mobile, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)");
            if ($stmt) {
                $stmt->bind_param("ss", $mobile, $name);
                $stmt->execute();
            }
        }
    }
    echo json_encode(["success" => true, "message" => "Customer profile & address updated in database"]);
    exit();
} elseif ($action == 'create-seller') {
    $name = isset($input['name']) ? trim($input['name']) : '';
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'mobile'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN mobile VARCHAR(15) DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO sellers (name, username, password, mobile) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $name, $username, $password, $mobile);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Seller Created"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Seller Exists or SQL Error"]);
} elseif ($action == 'sellers') {
    $result = $conn->query("SELECT * FROM sellers");
    $sellers = array();
    if ($result && $result !== true) {
        while ($row = $result->fetch_assoc()) {
            $sellers[] = $row;
        }
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
} elseif ($action == 'search-seller') {
    $rawTerm = isset($_GET['mobile']) ? trim($_GET['mobile']) : (isset($input['mobile']) ? trim($input['mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $rawTerm);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    $searchLike = "%" . $conn->real_escape_string($rawTerm) . "%";
    $searchDigits = "%" . $conn->real_escape_string($last10) . "%";

    $query = "SELECT * FROM sellers WHERE username LIKE '$searchLike' OR name LIKE '$searchLike'";
    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'mobile'");
    if ($colCheck && $colCheck->num_rows > 0) {
        $query = "SELECT * FROM sellers WHERE username LIKE '$searchLike' OR name LIKE '$searchLike' OR mobile LIKE '$searchDigits' OR mobile LIKE '$searchLike'";
    }

    $res = $conn->query($query);
    $sellers = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $sellers[] = $row;
        }
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
} elseif ($action == 'send-message') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $customer_mobile = isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '';
    $message = isset($input['message']) ? trim($input['message']) : '';
    $sender_type = isset($input['sender_type']) ? trim($input['sender_type']) : 'customer';
    $order_amount = isset($input['order_amount']) ? (float)$input['order_amount'] : (isset($input['amount']) ? (float)$input['amount'] : null);

    if (empty($seller_username) || empty($customer_mobile) || empty($message)) {
        echo json_encode(["success" => false, "message" => "Required fields missing"]);
        exit();
    }

    $items = array();
    $lines = explode("\n", $message);
    foreach ($lines as $line) {
        $trimmed = trim($line);
        if (!empty($trimmed)) {
            $items[] = array("text" => $trimmed, "status" => 0);
        }
    }
    $items_json = json_encode($items);

    if ($order_amount === null || $order_amount <= 0) {
        $calcAmt = 0.0;
        foreach ($items as $it) {
            if (preg_match('/₹\s*([\d\.]+)/u', $it['text'], $m)) {
                $calcAmt += (float)$m[1];
            }
        }
        if ($calcAmt > 0) {
            $order_amount = $calcAmt;
        }
    }

    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $seqCount = 1;
    $numRes = $conn->query("SELECT COUNT(*) as total FROM messages WHERE seller_username = '$escapedSeller' AND customer_mobile LIKE '$escapedLike'");
    if ($numRes && $nRow = $numRes->fetch_assoc()) {
        $seqCount = (int)$nRow['total'] + 1;
    }
    $order_id = "Order #" . $seqCount;
    $order_status = "Status";
    $logs_json = json_encode(array());

    $colCheckLogs = $conn->query("SHOW COLUMNS FROM messages LIKE 'logs_json'");
    if (!$colCheckLogs || $colCheckLogs->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN logs_json TEXT DEFAULT NULL");
    }

    $colCheckAmt = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
    if (!$colCheckAmt || $colCheckAmt->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT NULL");
    }

    if ($order_amount !== null && $order_amount > 0) {
        $stmt = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, logs_json, sender_type, is_read, payment_status, order_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 'unpaid', ?)");
        if ($stmt) {
            $stmt->bind_param("ssssssssd", $seller_username, $customer_mobile, $message, $items_json, $order_id, $order_status, $logs_json, $sender_type, $order_amount);
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Message sent"]);
                exit();
            }
        }
    } else {
        $stmt = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, logs_json, sender_type, is_read, payment_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 'unpaid')");
        if ($stmt) {
            $stmt->bind_param("ssssssss", $seller_username, $customer_mobile, $message, $items_json, $order_id, $order_status, $logs_json, $sender_type);
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Message sent"]);
                exit();
            }
        }
    }

    $stmtFallback = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, sender_type, is_read, payment_status) VALUES (?, ?, ?, ?, 0, 'unpaid')");
    if ($stmtFallback) {
        $stmtFallback->bind_param("ssss", $seller_username, $customer_mobile, $message, $sender_type);
        if ($stmtFallback->execute()) {
            echo json_encode(["success" => true, "message" => "Message sent (fallback)"]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "SQL Error"]);
} elseif ($action == 'update-item-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $items = isset($input['items']) ? $input['items'] : array();
    $items_json = json_encode($items);

    $seller_name = isset($input['seller_name']) ? trim($input['seller_name']) : 'SELLER';
    $item_num = isset($input['item_num']) ? (int)$input['item_num'] : 1;
    $status = isset($input['status']) ? (int)$input['status'] : 1;
    $time_str = date('d/m/Y, H:i');

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'logs_json'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN logs_json TEXT DEFAULT NULL");
    }

    $existing_logs = array();
    if ($msg_id > 0) {
        $res = $conn->query("SELECT logs_json FROM messages WHERE id = $msg_id");
        if ($res && $row = $res->fetch_assoc()) {
            if (!empty($row['logs_json'])) {
                $decoded = json_decode($row['logs_json'], true);
                if (is_array($decoded)) $existing_logs = $decoded;
            }
        }

        if ($status == 1 || $status == 2) {
            array_unshift($existing_logs, array(
                "item_num" => $item_num,
                "status" => $status,
                "seller_name" => strtoupper($seller_name),
                "timestamp" => $time_str
            ));
        }

        $logs_json = json_encode($existing_logs);
        $stmt = $conn->prepare("UPDATE messages SET items_json = ?, logs_json = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssi", $items_json, $logs_json, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "logs" => $existing_logs]);
} elseif ($action == 'update-order-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $status_text = isset($input['order_status']) ? trim($input['order_status']) : 'Ready';

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_status'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN order_status VARCHAR(20) DEFAULT 'Status'");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET order_status = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("si", $status_text, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
} elseif ($action == 'update-order-amount') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $amount = isset($input['order_amount']) ? (float)$input['order_amount'] : (isset($input['amount']) ? (float)$input['amount'] : 0.0);

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT 0.00");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET order_amount = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("di", $amount, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "order_amount" => $amount]);
    exit();
} elseif ($action == 'update-bill-image') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $bill_image = isset($input['bill_image']) ? trim($input['bill_image']) : '';

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'bill_image'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN bill_image LONGTEXT DEFAULT NULL");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET bill_image = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("si", $bill_image, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
    exit();
} elseif ($action == 'update-order-payment-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $payment_status = isset($input['payment_status']) ? trim($input['payment_status']) : 'paid';
    $payment_utr = isset($input['payment_utr']) ? trim($input['payment_utr']) : '';
    $paid_amount = isset($input['paid_amount']) ? (float)$input['paid_amount'] : (isset($input['amount']) ? (float)$input['amount'] : 0.0);
    $paid_at = isset($input['paid_at']) ? trim($input['paid_at']) : date('d/m/Y, H:i');

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET payment_status = ?, payment_utr = ?, paid_amount = ?, paid_at = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssdsi", $payment_status, $payment_utr, $paid_amount, $paid_at, $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Payment status saved in database"]);
    exit();
} elseif ($action == 'delete-message') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : (isset($_GET['message_id']) ? (int)$_GET['message_id'] : 0);
    if ($msg_id > 0) {
        $stmt = $conn->prepare("DELETE FROM messages WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $msg_id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
} elseif ($action == 'mark-read') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $searchLike = "%" . $last10 . "%";

    if (!empty($seller_username) && !empty($customer_mobile)) {
        $stmt = $conn->prepare("UPDATE messages SET is_read = 1 WHERE seller_username = ? AND customer_mobile LIKE ?");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $searchLike);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true]);
} elseif ($action == 'get-seller-conversations') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    if (empty($seller_username)) {
        echo json_encode(["success" => false, "conversations" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $query = "SELECT * FROM messages WHERE seller_username = '$escapedSeller' ORDER BY id DESC";
    $res = $conn->query($query);
    $conversations = array();
    $seenCust = array();

    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $c = $row['customer_mobile'];
            if (!in_array($c, $seenCust)) {
                $seenCust[] = $c;

                $unreadCount = 0;
                $countRes = $conn->query("SELECT COUNT(*) as cnt FROM messages WHERE seller_username = '$escapedSeller' AND customer_mobile = '$c' AND sender_type = 'customer' AND (is_read = 0 OR is_read IS NULL)");
                if ($countRes && $cntRow = $countRes->fetch_assoc()) {
                    $unreadCount = (int)$cntRow['cnt'];
                }

                // Query customers table to fetch real customer name by mobile number
                $cDigits = preg_replace('/[^0-9]/', '', $c);
                $cLast10 = (strlen($cDigits) >= 10) ? substr($cDigits, -10) : $cDigits;
                $cEscapedLike = "%" . $conn->real_escape_string($cLast10) . "%";

                $cName = "Customer ($c)";
                $custRes = $conn->query("SELECT name FROM customers WHERE mobile = '$c' OR mobile LIKE '$cEscapedLike' ORDER BY id DESC LIMIT 1");
                if ($custRes && $custRow = $custRes->fetch_assoc()) {
                    $dbName = trim($custRow['name']);
                    if (!empty($dbName) && $dbName !== 'Customer' && strpos($dbName, 'Customer') !== 0) {
                        $cName = $dbName;
                    }
                }

                $conversations[] = array(
                    "customer_mobile" => $c,
                    "customer_name" => $cName,
                    "name" => $cName,
                    "last_message" => isset($row['message']) ? $row['message'] : '',
                    "last_time" => isset($row['created_at']) ? $row['created_at'] : '',
                    "unread_count" => $unreadCount
                );
            }
        }
    }
    echo json_encode(["success" => true, "conversations" => $conversations]);
} elseif ($action == 'get-customer-conversations') {
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    if (empty($last10)) {
        echo json_encode(["success" => true, "conversations" => array()]);
        exit();
    }

    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";
    $query = "SELECT * FROM messages WHERE customer_mobile LIKE '$escapedLike' ORDER BY id DESC";
    $res = $conn->query($query);
    $conversations = array();
    $seenSellers = array();

    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $u = $row['seller_username'];
            if (!in_array($u, $seenSellers)) {
                $seenSellers[] = $u;

                $sName = $u;
                $sMobile = '';
                $sRes = $conn->query("SELECT * FROM sellers WHERE username = '$u' OR name = '$u' LIMIT 1");
                if ($sRes && $sRow = $sRes->fetch_assoc()) {
                    if (isset($sRow['name']) && !empty($sRow['name'])) $sName = $sRow['name'];
                    if (isset($sRow['mobile']) && !empty($sRow['mobile'])) $sMobile = $sRow['mobile'];
                }

                $conversations[] = array(
                    "seller_username" => $u,
                    "seller_name" => $sName,
                    "seller_mobile" => $sMobile,
                    "last_message" => isset($row['message']) ? $row['message'] : '',
                    "last_time" => isset($row['created_at']) ? $row['created_at'] : ''
                );
            }
        }
    }

    echo json_encode(["success" => true, "conversations" => $conversations]);
} elseif ($action == 'get-messages') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $searchLike = "%" . $last10 . "%";

    if (!empty($seller_username) && !empty($last10)) {
        $stmt = $conn->prepare("SELECT * FROM messages WHERE seller_username = ? AND customer_mobile LIKE ? ORDER BY id ASC");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $searchLike);
            $stmt->execute();
            $res = $stmt->get_result();
            $messages = array();
            if ($res) {
                while ($row = $res->fetch_assoc()) {
                    $messages[] = $row;
                }
            }
            echo json_encode(["success" => true, "messages" => $messages]);
            exit();
        }
    }
    echo json_encode(["success" => false, "messages" => array()]);
} elseif ($action == 'delete-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $stmt = $conn->prepare("DELETE FROM sellers WHERE username = ?");
    if ($stmt) {
        $stmt->bind_param("s", $username);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Seller Deleted"]);
} elseif ($action == 'seller-login') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $stmt = $conn->prepare("SELECT * FROM sellers WHERE username = ? AND password = ?");
    if ($stmt) {
        $stmt->bind_param("ss", $username, $password);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($res && $row = $res->fetch_assoc()) {
            echo json_encode(["success" => true, "seller" => $row]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
} elseif ($action == 'add-seller-product') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and product name are required"]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_products (seller_username, name, description, unit, qty, rate) VALUES (?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssssid", $seller_username, $name, $description, $unit, $qty, $rate);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Product added successfully",
                "product" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "description" => $description,
                    "unit" => $unit,
                    "qty" => $qty,
                    "rate" => $rate
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add product"]);
    exit();
} elseif ($action == 'get-seller-products') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "products" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_products WHERE seller_username = '$escapedSeller' ORDER BY id DESC");
    $products = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['qty'] = isset($row['qty']) ? (int)$row['qty'] : 1;
            $row['rate'] = (float)$row['rate'];
            $products[] = $row;
        }
    }
    echo json_encode(["success" => true, "products" => $products]);
    exit();
} elseif ($action == 'update-seller-product') {
    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;

    if ($id <= 0 || empty($name)) {
        echo json_encode(["success" => false, "message" => "Product ID and name required"]);
        exit();
    }

    $stmt = $conn->prepare("UPDATE seller_products SET name = ?, description = ?, unit = ?, qty = ?, rate = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("sssidi", $name, $description, $unit, $qty, $rate, $id);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Product updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to update product"]);
    exit();
} elseif ($action == 'delete-seller-product') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_products WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Product deleted"]);
    exit();
} elseif ($action == 'get-seller-units') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "units" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_units WHERE seller_username = '$escapedSeller' ORDER BY id ASC");
    $units = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $units[] = $row;
        }
    }
    echo json_encode(["success" => true, "units" => $units]);
    exit();
} elseif ($action == 'add-seller-unit') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $unit_name = isset($input['unit_name']) ? trim($input['unit_name']) : (isset($_GET['unit_name']) ? trim($_GET['unit_name']) : (isset($_POST['unit_name']) ? trim($_POST['unit_name']) : ''));

    if (empty($seller_username) || empty($unit_name)) {
        echo json_encode(["success" => false, "message" => "Seller username and unit name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedUnit = $conn->real_escape_string($unit_name);
    $chk = $conn->query("SELECT id FROM seller_units WHERE seller_username = '$escapedSeller' AND unit_name = '$escapedUnit' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        echo json_encode([
            "success" => true,
            "message" => "Unit already exists",
            "unit" => [
                "id" => (int)$row['id'],
                "seller_username" => $seller_username,
                "unit_name" => $unit_name
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_units (seller_username, unit_name) VALUES (?, ?)");
    if ($stmt) {
        $stmt->bind_param("ss", $seller_username, $unit_name);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Unit added",
                "unit" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "unit_name" => $unit_name
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add unit"]);
    exit();
} elseif ($action == 'update-seller-unit') {
    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $unit_name = isset($input['unit_name']) ? trim($input['unit_name']) : '';

    if ($id <= 0 || empty($unit_name)) {
        echo json_encode(["success" => false, "message" => "Unit ID and name required"]);
        exit();
    }

    $stmt = $conn->prepare("UPDATE seller_units SET unit_name = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("si", $unit_name, $id);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Unit updated"]);
    exit();
} elseif ($action == 'delete-seller-unit') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_units WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Unit deleted"]);
    exit();
} else {
    echo json_encode(["success" => true, "message" => "Daily Mart API Active"]);
}

$conn->close();
?>
