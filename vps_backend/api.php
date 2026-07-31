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

// Ensure required tables exist
$conn->query("CREATE TABLE IF NOT EXISTS admin (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$conn->query("CREATE TABLE IF NOT EXISTS sellers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) DEFAULT 'Seller Store',
    mobile VARCHAR(15) DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$conn->query("CREATE TABLE IF NOT EXISTS customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mobile VARCHAR(15) NOT NULL UNIQUE,
    name VARCHAR(100) DEFAULT 'Customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$conn->query("CREATE TABLE IF NOT EXISTS messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(50) NOT NULL,
    customer_mobile VARCHAR(15) NOT NULL,
    message TEXT NOT NULL,
    items_json TEXT DEFAULT NULL,
    order_id VARCHAR(20) DEFAULT NULL,
    order_status VARCHAR(20) DEFAULT 'Status',
    logs_json TEXT DEFAULT NULL,
    sender_type VARCHAR(10) DEFAULT 'customer',
    is_read TINYINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$conn->query("CREATE TABLE IF NOT EXISTS seller_sliders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(50) NOT NULL,
    tag VARCHAR(50) DEFAULT 'OFFER 🏷️',
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    bg_image_url LONGTEXT DEFAULT NULL,
    tag_bg_color VARCHAR(20) DEFAULT '#10B981',
    tag_shape VARCHAR(20) DEFAULT 'pill',
    title_color VARCHAR(20) DEFAULT '#FFFFFF',
    desc_color VARCHAR(20) DEFAULT '#E2E8F0',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// Safely alter existing table if columns missing
@$conn->query("ALTER TABLE seller_sliders ADD COLUMN tag_bg_color VARCHAR(20) DEFAULT '#10B981'");
@$conn->query("ALTER TABLE seller_sliders ADD COLUMN tag_shape VARCHAR(20) DEFAULT 'pill'");
@$conn->query("ALTER TABLE seller_sliders ADD COLUMN title_color VARCHAR(20) DEFAULT '#FFFFFF'");
@$conn->query("ALTER TABLE seller_sliders ADD COLUMN desc_color VARCHAR(20) DEFAULT '#E2E8F0'");
@$conn->query("ALTER TABLE seller_sliders MODIFY bg_image_url LONGTEXT DEFAULT NULL");

// Insert default admin if not exists
$checkAdmin = $conn->query("SELECT id FROM admin WHERE username='admin'");
if ($checkAdmin && $checkAdmin->num_rows == 0) {
    $conn->query("INSERT INTO admin (username, password) VALUES ('admin', '1234')");
}

$action = isset($_GET['action']) ? $_GET['action'] : '';
$rawInput = @file_get_contents('php://input');
$input = json_decode($rawInput, true);
if (!is_array($input)) $input = array();

if ($action == 'customer-login') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : 'Customer';
    if (!empty($mobile)) {
        $stmt = $conn->prepare("INSERT INTO customers (mobile, name) VALUES (?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name)");
        $stmt->bind_param("ss", $mobile, $name);
        $stmt->execute();
        echo json_encode(["success" => true, "role" => "customer", "mobile" => $mobile, "name" => $name]);
    } else {
        echo json_encode(["success" => false, "error" => "Mobile number required"]);
    }
    exit();
}

if ($action == 'seller-login') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $stmt = $conn->prepare("SELECT username, name, mobile FROM sellers WHERE username = ? AND password = ?");
    $stmt->bind_param("ss", $username, $password);
    $stmt->execute();
    $res = $stmt->get_result();
    if ($row = $res->fetch_assoc()) {
        echo json_encode(["success" => true, "role" => "seller", "username" => $row['username'], "name" => $row['name'], "mobile" => $row['mobile']]);
    } else {
        echo json_encode(["success" => false, "error" => "Invalid credentials"]);
    }
    exit();
}

if ($action == 'create-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $name = isset($input['name']) ? trim($input['name']) : 'Seller Store';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    if (!empty($username) && !empty($password)) {
        $stmt = $conn->prepare("INSERT INTO sellers (username, password, name, mobile) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("ssss", $username, $password, $name, $mobile);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Seller created successfully"]);
        } else {
            echo json_encode(["success" => false, "error" => "Username already exists"]);
        }
    } else {
        echo json_encode(["success" => false, "error" => "Username and password required"]);
    }
    exit();
}

if ($action == 'send-message') {
    $seller = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $customer = isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '';
    $msg = isset($input['message']) ? trim($input['message']) : '';
    $items = isset($input['items_json']) ? json_encode($input['items_json']) : NULL;
    $sender = isset($input['sender_type']) ? trim($input['sender_type']) : 'customer';

    if (!empty($seller) && !empty($customer) && !empty($msg)) {
        $seqRes = $conn->query("SELECT COUNT(*) as cnt FROM messages WHERE seller_username='$seller' AND customer_mobile='$customer'");
        $seqCount = 1;
        if ($seqRes && $seqRow = $seqRes->fetch_assoc()) {
            $seqCount = (int)$seqRow['cnt'] + 1;
        }
        $order_id = "Order " . $seqCount;

        $stmt = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, sender_type) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssssss", $seller, $customer, $msg, $items, $order_id, $sender);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message_id" => $conn->insert_id, "order_id" => $order_id]);
        } else {
            echo json_encode(["success" => false, "error" => "Failed to send message"]);
        }
    } else {
        echo json_encode(["success" => false, "error" => "Missing fields"]);
    }
    exit();
}

if ($action == 'update-item-status') {
    $msgId = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $itemNum = isset($input['item_num']) ? (int)$input['item_num'] : 0;
    $status = isset($input['status']) ? trim($input['status']) : '';
    $sellerName = isset($input['seller_name']) ? trim($input['seller_name']) : 'Seller';

    if ($msgId > 0 && $itemNum > 0 && !empty($status)) {
        $res = $conn->query("SELECT items_json, logs_json FROM messages WHERE id = $msgId");
        if ($res && $row = $res->fetch_assoc()) {
            $items = json_decode($row['items_json'], true);
            $logs = json_decode($row['logs_json'], true);
            if (!is_array($items)) $items = array();
            if (!is_array($logs)) $logs = array();

            foreach ($items as &$it) {
                if (isset($it['num']) && (int)$it['num'] === $itemNum) {
                    $it['status'] = $status;
                    break;
                }
            }

            $timestamp = date("d/m/Y, H:i");
            $newLog = "$itemNum. " . ($status == 'yes' ? '✔ (yes)' : ($status == 'no' ? '❌ (no)' : '☐ (reset)')) . " — " . strtoupper($sellerName) . " — " . $timestamp;
            $logs[] = $newLog;

            $updatedItems = json_encode($items);
            $updatedLogs = json_encode($logs);
            $stmt = $conn->prepare("UPDATE messages SET items_json = ?, logs_json = ? WHERE id = ?");
            $stmt->bind_param("ssi", $updatedItems, $updatedLogs, $msgId);
            $stmt->execute();
            echo json_encode(["success" => true, "items_json" => $items, "logs_json" => $logs]);
            exit();
        }
    }
    echo json_encode(["success" => false, "error" => "Invalid payload"]);
    exit();
}

if ($action == 'update-order-status') {
    $msgId = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $status = isset($input['order_status']) ? trim($input['order_status']) : 'Ready';

    if ($msgId > 0) {
        $stmt = $conn->prepare("UPDATE messages SET order_status = ? WHERE id = ?");
        $stmt->bind_param("si", $status, $msgId);
        $stmt->execute();
        echo json_encode(["success" => true, "order_status" => $status]);
        exit();
    }
    echo json_encode(["success" => false, "error" => "Invalid message ID"]);
    exit();
}

if ($action == 'delete-message') {
    $msgId = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    if ($msgId > 0) {
        $conn->query("DELETE FROM messages WHERE id = $msgId");
        echo json_encode(["success" => true, "message" => "Order deleted"]);
        exit();
    }
    echo json_encode(["success" => false, "error" => "Invalid message ID"]);
    exit();
}

if ($action == 'get-messages') {
    $seller = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $customer = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';

    $stmt = $conn->prepare("SELECT * FROM messages WHERE seller_username = ? AND customer_mobile = ? ORDER BY id ASC");
    $stmt->bind_param("ss", $seller, $customer);
    $stmt->execute();
    $res = $stmt->get_result();
    $messages = [];
    while ($row = $res->fetch_assoc()) {
        if ($row['items_json']) $row['items_json'] = json_decode($row['items_json'], true);
        if ($row['logs_json']) $row['logs_json'] = json_decode($row['logs_json'], true);
        if (isset($row['order_id'])) {
            $row['order_id'] = str_replace('#', '', $row['order_id']);
        }
        $messages[] = $row;
    }
    echo json_encode(["success" => true, "messages" => $messages]);
    exit();
}

// SLIDER APIS FOR SELLER
if ($action == 'add-seller-slider') {
    $seller = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $tag = isset($input['tag']) ? trim($input['tag']) : 'OFFER 🏷️';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $desc = isset($input['description']) ? trim($input['description']) : '';
    $bg = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tagBgColor = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tagShape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $titleColor = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $descColor = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';

    if (!empty($seller) && !empty($title) && !empty($desc)) {
        $stmt = $conn->prepare("INSERT INTO seller_sliders (seller_username, tag, title, description, bg_image_url, tag_bg_color, tag_shape, title_color, desc_color) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("sssssssss", $seller, $tag, $title, $desc, $bg, $tagBgColor, $tagShape, $titleColor, $descColor);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "slider_id" => $conn->insert_id]);
        } else {
            echo json_encode(["success" => false, "error" => "Failed to add slider"]);
        }
    } else {
        echo json_encode(["success" => false, "error" => "Title and description required"]);
    }
    exit();
}

if ($action == 'update-seller-slider') {
    $sliderId = isset($input['slider_id']) ? (int)$input['slider_id'] : 0;
    $tag = isset($input['tag']) ? trim($input['tag']) : 'OFFER 🏷️';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $bgImageUrl = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tagBgColor = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tagShape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $titleColor = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $descColor = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';

    if ($sliderId > 0 && $title !== '') {
        $stmt = $conn->prepare("UPDATE seller_sliders SET tag=?, title=?, description=?, bg_image_url=?, tag_bg_color=?, tag_shape=?, title_color=?, desc_color=? WHERE id=?");
        $stmt->bind_param("ssssssssi", $tag, $title, $description, $bgImageUrl, $tagBgColor, $tagShape, $titleColor, $descColor, $sliderId);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Slider updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "error" => "Failed to update slider"]);
    exit();
}

if ($action == 'delete-seller-slider') {
    $sliderId = isset($input['slider_id']) ? (int)$input['slider_id'] : 0;
    if ($sliderId > 0) {
        $conn->query("DELETE FROM seller_sliders WHERE id = $sliderId");
        echo json_encode(["success" => true, "message" => "Slider deleted"]);
        exit();
    }
    echo json_encode(["success" => false, "error" => "Invalid slider ID"]);
    exit();
}

if ($action == 'get-seller-sliders') {
    $seller = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $stmt = $conn->prepare("SELECT * FROM seller_sliders WHERE seller_username = ? ORDER BY id DESC");
    $stmt->bind_param("s", $seller);
    $stmt->execute();
    $res = $stmt->get_result();
    $sliders = [];
    while ($row = $res->fetch_assoc()) {
        $sliders[] = $row;
    }
    echo json_encode(["success" => true, "sliders" => $sliders]);
    exit();
}

if ($action == 'get-customer-conversations') {
    $customer = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : '';
    $sql = "SELECT m.seller_username, s.name as seller_name, s.mobile as seller_mobile,
                   (SELECT message FROM messages WHERE seller_username = m.seller_username AND customer_mobile = m.customer_mobile ORDER BY id DESC LIMIT 1) as last_message,
                   (SELECT created_at FROM messages WHERE seller_username = m.seller_username AND customer_mobile = m.customer_mobile ORDER BY id DESC LIMIT 1) as last_time
            FROM messages m
            JOIN sellers s ON m.seller_username = s.username
            WHERE m.customer_mobile = ?
            GROUP BY m.seller_username, s.name, s.mobile";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $customer);
    $stmt->execute();
    $res = $stmt->get_result();
    $chats = [];
    while ($row = $res->fetch_assoc()) {
        $chats[] = $row;
    }
    echo json_encode(["success" => true, "conversations" => $chats]);
    exit();
}

if ($action == 'get-seller-conversations') {
    $seller = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '';
    $sql = "SELECT m.customer_mobile, c.name as customer_name,
                   (SELECT message FROM messages WHERE seller_username = m.seller_username AND customer_mobile = m.customer_mobile ORDER BY id DESC LIMIT 1) as last_message,
                   (SELECT created_at FROM messages WHERE seller_username = m.seller_username AND customer_mobile = m.customer_mobile ORDER BY id DESC LIMIT 1) as last_time
            FROM messages m
            LEFT JOIN customers c ON m.customer_mobile = c.mobile
            WHERE m.seller_username = ?
            GROUP BY m.customer_mobile, c.name";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $seller);
    $stmt->execute();
    $res = $stmt->get_result();
    $chats = [];
    while ($row = $res->fetch_assoc()) {
        $chats[] = $row;
    }
    echo json_encode(["success" => true, "conversations" => $chats]);
    exit();
}

if ($action == 'search-seller') {
    $q = isset($_GET['query']) ? trim($_GET['query']) : '';
    $stmt = $conn->prepare("SELECT username, name, mobile FROM sellers WHERE mobile LIKE ? OR username LIKE ? OR name LIKE ?");
    $param = "%$q%";
    $stmt->bind_param("sss", $param, $param, $param);
    $stmt->execute();
    $res = $stmt->get_result();
    $sellers = [];
    while ($row = $res->fetch_assoc()) {
        $sellers[] = $row;
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
    exit();
}

echo json_encode(["success" => true, "status" => "API Online"]);
