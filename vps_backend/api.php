<?php
// Daily Mart VPS Backend API - Updated: 2026-08-18 (PHP 8.1+ MySQLi Safe Exception Handling)
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: *");
header("Access-Control-Allow-Methods: *");
header("Content-Type: application/json");

ini_set('display_errors', 0);
error_reporting(0);

if (function_exists('mysqli_report')) {
    @mysqli_report(MYSQLI_REPORT_OFF);
}

date_default_timezone_set('Asia/Kolkata');

$host = "localhost";
$user = "daily_mart";
$pass = "DWZYHcAxSars3di8";
$dbname = "daily_mart";

try {
    $conn = @new mysqli($host, $user, $pass, $dbname);
} catch (Throwable $e) {
    echo json_encode(["success" => false, "error" => "DB Connection Failed: " . $e->getMessage()]);
    exit();
}

if (!$conn || $conn->connect_error) {
    echo json_encode(["success" => false, "error" => "DB Connection Error"]);
    exit();
}

$rawInput = @file_get_contents('php://input');
$input = json_decode($rawInput, true);
if (!is_array($input)) $input = array();

$action = isset($_GET['action']) ? $_GET['action'] : '';
if (empty($action) && isset($input['action'])) $action = $input['action'];
if (empty($action) && isset($_POST['action'])) $action = $_POST['action'];

if (empty($action)) {
    foreach ($_GET as $k => $v) {
        if ($k != 'seller_username' && $k != 'customer_mobile' && $k != 'mobile' && $k != 'id' && $k != 'username') {
            $action = $k;
            break;
        }
    }
}

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

// 3. Auto-check & create delivery status tracking columns in messages table
$colCheckDelStatus = $conn->query("SHOW COLUMNS FROM messages LIKE 'delivery_status'");
if (!$colCheckDelStatus || $colCheckDelStatus->num_rows == 0) {
    @$conn->query("ALTER TABLE messages ADD COLUMN delivery_status VARCHAR(50) DEFAULT 'pending', ADD COLUMN delivered_by VARCHAR(100) DEFAULT NULL, ADD COLUMN picked_up_at VARCHAR(50) DEFAULT NULL, ADD COLUMN delivered_at VARCHAR(50) DEFAULT NULL, ADD COLUMN cancel_reason VARCHAR(255) DEFAULT NULL, ADD COLUMN cancelled_at VARCHAR(50) DEFAULT NULL");
}

// 3b. Auto-check & create matching tracking columns in customer_orders table
$colCheckCustOrdPay = $conn->query("SHOW COLUMNS FROM customer_orders LIKE 'payment_status'");
if (!$colCheckCustOrdPay || $colCheckCustOrdPay->num_rows == 0) {
    @$conn->query("ALTER TABLE customer_orders ADD COLUMN payment_status VARCHAR(50) DEFAULT 'unpaid', ADD COLUMN payment_utr VARCHAR(100) DEFAULT NULL, ADD COLUMN paid_amount DECIMAL(10,2) DEFAULT 0.00, ADD COLUMN paid_at VARCHAR(50) DEFAULT NULL, ADD COLUMN delivery_status VARCHAR(50) DEFAULT 'pending', ADD COLUMN delivered_by VARCHAR(100) DEFAULT NULL, ADD COLUMN picked_up_at VARCHAR(50) DEFAULT NULL, ADD COLUMN delivered_at VARCHAR(50) DEFAULT NULL, ADD COLUMN cancel_reason VARCHAR(255) DEFAULT NULL, ADD COLUMN cancelled_at VARCHAR(50) DEFAULT NULL");
}

// 3c. Auto-sync messages table fields into customer_orders table
@$conn->query("UPDATE customer_orders co JOIN messages m ON co.order_number = m.order_id OR co.id = m.id SET co.payment_status = m.payment_status, co.payment_utr = m.payment_utr, co.paid_amount = m.paid_amount, co.paid_at = m.paid_at, co.delivery_status = m.delivery_status, co.delivered_by = m.delivered_by, co.picked_up_at = m.picked_up_at, co.delivered_at = m.delivered_at, co.cancel_reason = m.cancel_reason, co.cancelled_at = m.cancelled_at, co.order_status = m.order_status WHERE m.payment_status IS NOT NULL OR m.delivery_status IS NOT NULL");

// 4. Auto-check & create seller_sliders table in database
$conn->query("CREATE TABLE IF NOT EXISTS seller_sliders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    tag VARCHAR(255) DEFAULT 'SPECIAL OFFER 🏷️',
    title VARCHAR(255) DEFAULT '',
    description TEXT DEFAULT NULL,
    bg_image_url LONGTEXT DEFAULT NULL,
    tag_bg_color VARCHAR(50) DEFAULT '#10B981',
    tag_shape VARCHAR(50) DEFAULT 'pill',
    title_color VARCHAR(50) DEFAULT '#FFFFFF',
    desc_color VARCHAR(50) DEFAULT '#E2E8F0',
    section VARCHAR(255) DEFAULT 'Top Banner',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$colCheckSliderSec = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'section'");
if (!$colCheckSliderSec || $colCheckSliderSec->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sliders ADD COLUMN section VARCHAR(255) DEFAULT 'Top Banner'");
}

// 5. Auto-check & create delivery_boys table in database
$conn->query("CREATE TABLE IF NOT EXISTS delivery_boys (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    mobile VARCHAR(20) NOT NULL,
    vehicle VARCHAR(100) DEFAULT 'Bike',
    location VARCHAR(255) DEFAULT NULL,
    role VARCHAR(50) DEFAULT 'delivery_boy',
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$colCheckDelLoc = $conn->query("SHOW COLUMNS FROM delivery_boys LIKE 'location'");
if (!$colCheckDelLoc || $colCheckDelLoc->num_rows == 0) {
    @$conn->query("ALTER TABLE delivery_boys ADD COLUMN location VARCHAR(255) DEFAULT NULL");
}

$colCheckSelLoc = $conn->query("SHOW COLUMNS FROM sellers LIKE 'location'");
if (!$colCheckSelLoc || $colCheckSelLoc->num_rows == 0) {
    @$conn->query("ALTER TABLE sellers ADD COLUMN location VARCHAR(255) DEFAULT NULL");
}

// 6. Auto-check & create locations table in database
$conn->query("CREATE TABLE IF NOT EXISTS locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// 7. Auto-check & create seller_products table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT DEFAULT NULL,
    unit VARCHAR(50) NOT NULL DEFAULT 'Pcs',
    category VARCHAR(255) DEFAULT NULL,
    qty INT NOT NULL DEFAULT 1,
    rate DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    image_url LONGTEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckQty = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'qty'");
if (!$colCheckQty || $colCheckQty->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN qty INT NOT NULL DEFAULT 1");
}

$colCheckProdImg = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'image_url'");
if (!$colCheckProdImg || $colCheckProdImg->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN image_url LONGTEXT DEFAULT NULL");
}

// 8. Auto-check & create seller_units table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_units (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

// 9. Auto-check & create app_settings table for Global Header Theme Sync if missing
@$conn->query("CREATE TABLE IF NOT EXISTS app_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value LONGTEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckCat = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'category'");
if (!$colCheckCat || $colCheckCat->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN category VARCHAR(255) DEFAULT NULL");
}

// 10. Auto-check & create seller_categories table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    image_url LONGTEXT DEFAULT NULL,
    color VARCHAR(50) DEFAULT '#8B5CF6',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckCatColor = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'color'");
if (!$colCheckCatColor || $colCheckCatColor->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN color VARCHAR(50) DEFAULT '#8B5CF6'");
}

// 11. Auto-check & create seller_sections table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_sections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(50) DEFAULT '🏷️',
    bg_color VARCHAR(50) DEFAULT '#FFFFFF',
    text_color VARCHAR(50) DEFAULT '#0F172A',
    columns INT DEFAULT 2,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckSecBg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'bg_color'");
if (!$colCheckSecBg || $colCheckSecBg->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sections ADD COLUMN bg_color VARCHAR(50) DEFAULT '#FFFFFF'");
}

$colCheckSecCols = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'columns'");
if (!$colCheckSecCols || $colCheckSecCols->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sections ADD COLUMN columns INT DEFAULT 2");
}

$colCheckSecCol = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'section'");
if (!$colCheckSecCol || $colCheckSecCol->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_products ADD COLUMN section VARCHAR(255) DEFAULT NULL");
}

// 12. Auto-check & create seller_sliders table if missing
@$conn->query("CREATE TABLE IF NOT EXISTS seller_sliders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL,
    tag VARCHAR(255) DEFAULT '',
    title VARCHAR(255) DEFAULT '',
    description TEXT DEFAULT NULL,
    bg_image_url LONGTEXT DEFAULT NULL,
    tag_bg_color VARCHAR(50) DEFAULT '#10B981',
    tag_shape VARCHAR(50) DEFAULT 'pill',
    title_color VARCHAR(50) DEFAULT '#FFFFFF',
    desc_color VARCHAR(50) DEFAULT '#E2E8F0',
    section VARCHAR(255) DEFAULT 'Top Banner',
    overlay_dim FLOAT DEFAULT 0.0,
    remove_white_bg TINYINT(1) DEFAULT 0,
    img_fit VARCHAR(50) DEFAULT 'cover',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckSliderSec = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'section'");
if (!$colCheckSliderSec || $colCheckSliderSec->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sliders ADD COLUMN section VARCHAR(255) DEFAULT 'Top Banner'");
}

if ($action == 'get-header-theme') {
    $res = $conn->query("SELECT setting_value FROM app_settings WHERE setting_key = 'global_header_theme'");
    if ($res && $row = $res->fetch_assoc()) {
        $themeConfig = json_decode($row['setting_value'], true);
        if (is_array($themeConfig)) {
            echo json_encode(["success" => true, "theme" => $themeConfig]);
            exit();
        }
    }
    echo json_encode(["success" => true, "theme" => null]);
    exit();
} elseif ($action == 'update-header-theme') {
    $themeConfig = isset($input) && is_array($input) ? $input : array();
    $jsonVal = json_encode($themeConfig);

    $stmt = $conn->prepare("INSERT INTO app_settings (setting_key, setting_value) VALUES ('global_header_theme', ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)");
    if ($stmt) {
        $stmt->bind_param("s", $jsonVal);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Header theme saved in database"]);
    exit();
} elseif ($action == 'customer-login') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $address_json = isset($input['address_json']) ? (is_array($input['address_json']) ? json_encode($input['address_json']) : trim($input['address_json'])) : '';

    $cName = 'Customer';
    $cAddr = '';

    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
        $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

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
} elseif ($action == 'locations' || $action == 'get-locations') {
    $res = $conn->query("SELECT * FROM locations ORDER BY id ASC");
    $locations = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $locations[] = $row;
        }
    }
    echo json_encode(["success" => true, "locations" => $locations]);
    exit();
} elseif ($action == 'add-location') {
    $locName = isset($input['name']) ? trim($input['name']) : (isset($input['location_name']) ? trim($input['location_name']) : '');
    if (!empty($locName)) {
        $stmt = $conn->prepare("INSERT IGNORE INTO locations (name) VALUES (?)");
        if ($stmt) {
            $stmt->bind_param("s", $locName);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Location Saved"]);
    exit();
} elseif ($action == 'create-delivery-boy') {
    $name = isset($input['name']) ? trim($input['name']) : '';
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $vehicle = isset($input['vehicle']) ? trim($input['vehicle']) : 'Bike';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username) && !empty($password) && !empty($name)) {
        $stmt = $conn->prepare("INSERT INTO delivery_boys (name, username, password, mobile, vehicle, location) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), password=VALUES(password), mobile=VALUES(mobile), vehicle=VALUES(vehicle), location=VALUES(location)");
        if ($stmt) {
            $stmt->bind_param("ssssss", $name, $username, $password, $mobile, $vehicle, $location);
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Delivery Boy Account Created Successfully"]);
                exit();
            }
        }
    }
    echo json_encode(["success" => false, "message" => "Required fields missing or SQL error"]);
    exit();
} elseif ($action == 'update-delivery-boy') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $vehicle = isset($input['vehicle']) ? trim($input['vehicle']) : 'Bike';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username)) {
        $stmt = $conn->prepare("UPDATE delivery_boys SET name = ?, password = ?, mobile = ?, vehicle = ?, location = ? WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("ssssss", $name, $password, $mobile, $vehicle, $location, $username);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Delivery partner updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid username"]);
    exit();
} elseif ($action == 'update-delivery-status') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $delivery_status = isset($input['delivery_status']) ? trim($input['delivery_status']) : 'Picked Up';
    $delivered_by = isset($input['delivered_by']) ? trim($input['delivered_by']) : '';
    $time_str = date('d/m/Y, H:i');

    if ($msg_id > 0) {
        $msgRow = $conn->query("SELECT order_id FROM messages WHERE id = $msg_id LIMIT 1");
        $ordNum = ($msgRow && $r = $msgRow->fetch_assoc()) ? $r['order_id'] : "#DM-" . (1000 + $msg_id);
        $escapedDelBy = $conn->real_escape_string($delivered_by);

        $lowerStatus = strtolower($delivery_status);
        if ($lowerStatus == 'picked up' || $lowerStatus == 'picked_up' || $lowerStatus == 'out for delivery') {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = ?, delivered_by = ?, picked_up_at = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("sssi", $delivery_status, $delivered_by, $time_str, $msg_id);
                $stmt->execute();
            }
            @$conn->query("UPDATE customer_orders SET delivery_status = '$delivery_status', delivered_by = '$escapedDelBy', picked_up_at = '$time_str' WHERE order_number = '$ordNum' OR id = $msg_id");
        } elseif ($lowerStatus == 'delivered') {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = 'Delivered', order_status = 'Delivered', delivered_by = ?, delivered_at = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $delivered_by, $time_str, $msg_id);
                $stmt->execute();
            }
            @$conn->query("UPDATE customer_orders SET delivery_status = 'Delivered', order_status = 'Delivered', delivered_by = '$escapedDelBy', delivered_at = '$time_str' WHERE order_number = '$ordNum' OR id = $msg_id");
        } else {
            $stmt = $conn->prepare("UPDATE messages SET delivery_status = ?, delivered_by = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $delivery_status, $delivered_by, $msg_id);
                $stmt->execute();
            }
            @$conn->query("UPDATE customer_orders SET delivery_status = '$delivery_status', delivered_by = '$escapedDelBy' WHERE order_number = '$ordNum' OR id = $msg_id");
        }
        echo json_encode(["success" => true, "message" => "Delivery status updated in database"]);
        exit();
    }
    echo json_encode(["success" => false, "message" => "Invalid message ID"]);
    exit();
} elseif ($action == 'delivery-boys') {
    $res = $conn->query("SELECT * FROM delivery_boys ORDER BY id DESC");
    $delivery_boys = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $delivery_boys[] = $row;
        }
    }
    echo json_encode(["success" => true, "delivery_boys" => $delivery_boys]);
    exit();
} elseif ($action == 'delete-delivery-boy') {
    $username = isset($input['username']) ? trim($input['username']) : (isset($_GET['username']) ? trim($_GET['username']) : '');
    if (!empty($username)) {
        $stmt = $conn->prepare("DELETE FROM delivery_boys WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("s", $username);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Delivery Boy Account Deleted"]);
    exit();
} elseif ($action == 'delivery-boy-login') {
    $username = isset($input['username']) ? trim($input['username']) : (isset($_GET['username']) ? trim($_GET['username']) : '');
    $password = isset($input['password']) ? trim($input['password']) : (isset($_GET['password']) ? trim($_GET['password']) : '');

    $escapedUser = $conn->real_escape_string($username);

    $digits = preg_replace('/[^0-9]/', '', $username);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $query = "SELECT * FROM delivery_boys WHERE (LOWER(username) = LOWER('$escapedUser') OR LOWER(name) = LOWER('$escapedUser')" . (!empty($last10) ? " OR mobile = '$username' OR mobile LIKE '$escapedLike'" : "") . ") ORDER BY id DESC LIMIT 1";

    $res = $conn->query($query);
    if ($res && $row = $res->fetch_assoc()) {
        $dbPass = trim($row['password'] ?? '');
        $passMatch = ($dbPass === $password) || (strtolower($dbPass) === strtolower($password));
        if ($passMatch) {
            echo json_encode(["success" => true, "delivery_boy" => $row]);
            exit();
        } else {
            echo json_encode(["success" => false, "message" => "Incorrect Password"]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "Invalid Delivery Boy credentials"]);
    exit();
} elseif ($action == 'create-seller') {
    $name = isset($input['name']) ? trim($input['name']) : '';
    $username = isset($input['username']) ? trim($input['username']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $location = isset($input['location']) ? trim($input['location']) : '';

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'mobile'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN mobile VARCHAR(15) DEFAULT NULL");
    }

    $colCheckLoc = $conn->query("SHOW COLUMNS FROM sellers LIKE 'location'");
    if (!$colCheckLoc || $colCheckLoc->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN location VARCHAR(255) DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO sellers (name, username, password, mobile, location) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name=VALUES(name), password=VALUES(password), mobile=VALUES(mobile), location=VALUES(location)");
    if ($stmt) {
        $stmt->bind_param("sssss", $name, $username, $password, $mobile, $location);
        if ($stmt->execute()) {
            echo json_encode(["success" => true, "message" => "Seller Created"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Seller Exists or SQL Error"]);
} elseif ($action == 'update-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $password = isset($input['password']) ? trim($input['password']) : '';
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : '';
    $location = isset($input['location']) ? trim($input['location']) : '';

    if (!empty($username)) {
        $stmt = $conn->prepare("UPDATE sellers SET name = ?, password = ?, mobile = ?, location = ? WHERE username = ?");
        if ($stmt) {
            $stmt->bind_param("sssss", $name, $password, $mobile, $location, $username);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Seller updated successfully"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid username"]);
    exit();
} elseif ($action == 'sellers') {
    $result = $conn->query("SELECT * FROM sellers ORDER BY id DESC");
    $sellers = array();
    if ($result && $result !== true) {
        while ($row = $result->fetch_assoc()) {
            $sellers[] = $row;
        }
    }
    echo json_encode(["success" => true, "sellers" => $sellers]);
    exit();
} elseif ($action == 'get-seller-sliders') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    $escapedSeller = $conn->real_escape_string($seller_username);

    $query = "SELECT * FROM seller_sliders ORDER BY id DESC";
    if (!empty($escapedSeller)) {
        $query = "SELECT * FROM seller_sliders WHERE seller_username = '$escapedSeller' ORDER BY id DESC";
    }

    $res = $conn->query($query);
    $sliders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['section'] = (isset($row['section']) && !empty(trim($row['section']))) ? trim($row['section']) : 'Top Banner';
            $row['position'] = (isset($row['position']) && !empty(trim($row['position']))) ? trim($row['position']) : 'internal';
            $row['overlay_dim'] = isset($row['overlay_dim']) ? (float)$row['overlay_dim'] : 0.0;
            $row['remove_white_bg'] = isset($row['remove_white_bg']) ? (int)$row['remove_white_bg'] : 0;
            $row['img_fit'] = isset($row['img_fit']) ? $row['img_fit'] : 'cover';
            $sliders[] = $row;
        }
    }
    echo json_encode(["success" => true, "sliders" => $sliders]);
    exit();
} elseif ($action == 'add-seller-slider') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $tag = isset($input['tag']) ? trim($input['tag']) : 'SPECIAL OFFER 🏷️';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $bg_image_url = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tag_bg_color = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tag_shape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $title_color = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $desc_color = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';
    $section = isset($input['section']) ? trim($input['section']) : 'Top Banner';
    if (empty($section)) $section = 'Top Banner';
    $position = isset($input['position']) ? trim($input['position']) : 'internal';
    if (empty($position)) $position = 'internal';
    $overlay_dim = isset($input['overlay_dim']) ? (float)$input['overlay_dim'] : 0.0;
    $remove_white_bg = isset($input['remove_white_bg']) ? (int)$input['remove_white_bg'] : 0;
    $img_fit = isset($input['img_fit']) ? trim($input['img_fit']) : 'cover';

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    if (empty($title) && empty($tag) && empty($description) && (empty($bg_image_url) || $bg_image_url == 'none')) {
        echo json_encode(["success" => false, "message" => "Slider content or image required"]);
        exit();
    }

    $colCheckOverlay = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'overlay_dim'");
    if (!$colCheckOverlay || $colCheckOverlay->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN overlay_dim DECIMAL(3,2) DEFAULT 0.00, ADD COLUMN remove_white_bg INT DEFAULT 0, ADD COLUMN img_fit VARCHAR(50) DEFAULT 'cover'");
    }

    $colCheckSec = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'section'");
    if (!$colCheckSec || $colCheckSec->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN section VARCHAR(255) DEFAULT 'Top Banner'");
    }

    $colCheckPos = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'position'");
    if (!$colCheckPos || $colCheckPos->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN position VARCHAR(50) DEFAULT 'internal'");
    }

    $stmt = $conn->prepare("INSERT INTO seller_sliders (seller_username, tag, title, description, bg_image_url, tag_bg_color, tag_shape, title_color, desc_color, section, position, overlay_dim, remove_white_bg, img_fit) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssssssssssdisi", $seller_username, $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color, $section, $position, $overlay_dim, $remove_white_bg, $img_fit);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Slider saved permanently in database",
                "slider" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "tag" => $tag,
                    "title" => $title,
                    "description" => $description,
                    "bg_image_url" => $bg_image_url,
                    "tag_bg_color" => $tag_bg_color,
                    "tag_shape" => $tag_shape,
                    "title_color" => $title_color,
                    "desc_color" => $desc_color,
                    "section" => $section,
                    "position" => $position,
                    "overlay_dim" => $overlay_dim,
                    "remove_white_bg" => $remove_white_bg,
                    "img_fit" => $img_fit,
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add slider"]);
    exit();
} elseif ($action == 'update-seller-slider') {
    $slider_id = isset($input['slider_id']) ? (int)$input['slider_id'] : (isset($input['id']) ? (int)$input['id'] : 0);
    $tag = isset($input['tag']) ? trim($input['tag']) : '';
    $title = isset($input['title']) ? trim($input['title']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $bg_image_url = isset($input['bg_image_url']) ? trim($input['bg_image_url']) : '';
    $tag_bg_color = isset($input['tag_bg_color']) ? trim($input['tag_bg_color']) : '#10B981';
    $tag_shape = isset($input['tag_shape']) ? trim($input['tag_shape']) : 'pill';
    $title_color = isset($input['title_color']) ? trim($input['title_color']) : '#FFFFFF';
    $desc_color = isset($input['desc_color']) ? trim($input['desc_color']) : '#E2E8F0';
    $section = isset($input['section']) ? trim($input['section']) : 'Top Banner';
    if (empty($section)) $section = 'Top Banner';
    $position = isset($input['position']) ? trim($input['position']) : 'internal';
    if (empty($position)) $position = 'internal';
    $overlay_dim = isset($input['overlay_dim']) ? (float)$input['overlay_dim'] : 0.0;
    $remove_white_bg = isset($input['remove_white_bg']) ? (int)$input['remove_white_bg'] : 0;
    $img_fit = isset($input['img_fit']) ? trim($input['img_fit']) : 'cover';

    $colCheckSec = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'section'");
    if (!$colCheckSec || $colCheckSec->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN section VARCHAR(255) DEFAULT 'Top Banner'");
    }

    $colCheckPos = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'position'");
    if (!$colCheckPos || $colCheckPos->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN position VARCHAR(50) DEFAULT 'internal'");
    }

    if ($slider_id > 0) {
        $stmt = $conn->prepare("UPDATE seller_sliders SET tag = ?, title = ?, description = ?, bg_image_url = ?, tag_bg_color = ?, tag_shape = ?, title_color = ?, desc_color = ?, section = ?, position = ?, overlay_dim = ?, remove_white_bg = ?, img_fit = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssssssssssdisi", $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color, $section, $position, $overlay_dim, $remove_white_bg, $img_fit, $slider_id);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Slider updated in database"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid Slider ID"]);
    exit();
} elseif ($action == 'delete-seller-slider') {
    $slider_id = isset($input['slider_id']) ? (int)$input['slider_id'] : (isset($_GET['slider_id']) ? (int)$_GET['slider_id'] : 0);
    if ($slider_id > 0) {
        $conn->query("DELETE FROM seller_sliders WHERE id = $slider_id");
    }
    echo json_encode(["success" => true, "message" => "Slider deleted from database"]);
    exit();
} elseif ($action == 'update-bill-image' || $action == 'save-order-bill-image') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $bill_image = isset($input['bill_image']) ? trim($input['bill_image']) : '';

    $colCheckBill = $conn->query("SHOW COLUMNS FROM messages LIKE 'bill_image'");
    if (!$colCheckBill || $colCheckBill->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN bill_image LONGTEXT DEFAULT NULL");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET bill_image = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("si", $bill_image, $msg_id);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Bill photo saved in database"]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Invalid Message ID"]);
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
            if (!empty($dbName) && $dbName !== 'Customer') $cName = $dbName;
            if (!empty($row['address_json']) && $row['address_json'] !== '[]' && $row['address_json'] !== 'null') {
                $cAddr = $row['address_json'];
            }
        }

        if (empty($cAddr)) {
            $resMsg = $conn->query("SELECT customer_name, delivery_address FROM messages WHERE (customer_mobile = '$mobile' OR customer_mobile LIKE '$escapedLike') AND delivery_address IS NOT NULL AND delivery_address != '' ORDER BY id DESC LIMIT 1");
            if ($resMsg && $rowMsg = $resMsg->fetch_assoc()) {
                if ($cName === 'Customer' && !empty($rowMsg['customer_name'])) {
                    $cName = trim($rowMsg['customer_name']);
                }
                $rawAddr = trim($rowMsg['delivery_address'] ?? '');
                if (!empty($rawAddr)) {
                    $cAddr = json_encode([
                        [
                            'id' => (string)time(),
                            'tag' => 'Home',
                            'houseNo' => $rawAddr,
                            'locality' => '',
                            'landmark' => '',
                            'city' => 'Raniganj',
                            'pincode' => ''
                        ]
                    ]);
                }
            }
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
} elseif ($action == 'get-next-order-id') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    $escapedSeller = $conn->real_escape_string($seller_username);

    $orderCount = 0;
    $cntQuery = !empty($seller_username)
        ? "SELECT COUNT(*) as total_orders FROM messages WHERE (seller_username = '$escapedSeller' OR seller_username LIKE '%$escapedSeller%') AND (items_json IS NOT NULL AND items_json != '' OR message LIKE '%ORDER%')"
        : "SELECT COUNT(*) as total_orders FROM messages WHERE items_json IS NOT NULL AND items_json != '' OR message LIKE '%ORDER%'";

    $cntRes = $conn->query($cntQuery);
    if ($cntRes && $cRow = $cntRes->fetch_assoc()) {
        $orderCount = (int)$cRow['total_orders'];
    }

    $nextNum = 1001 + $orderCount;
    $nextOrderId = "#DM-" . $nextNum;

    echo json_encode([
        "success" => true,
        "next_order_id" => $nextOrderId,
        "order_number" => $nextOrderId,
        "sequence" => $nextNum,
        "total_orders" => $orderCount
    ]);
    exit();
} elseif ($action == 'send-message') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $customer_mobile = isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '';
    $message = isset($input['message']) ? trim($input['message']) : '';
    $sender_type = isset($input['sender_type']) ? trim($input['sender_type']) : 'customer';
    $custom_order_id = isset($input['order_id']) ? trim($input['order_id']) : '';

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

    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedSeller = $conn->real_escape_string($seller_username);

    // Dynamic deletion-proof order ID calculation
    if (!empty($custom_order_id) && $custom_order_id !== 'Status' && $custom_order_id !== 'null') {
        $order_id = $custom_order_id;
    } else {
        $orderCount = 0;
        $cntRes = $conn->query("SELECT COUNT(*) as total_orders FROM messages WHERE (seller_username = '$escapedSeller' OR seller_username LIKE '%$escapedSeller%') AND (items_json IS NOT NULL AND items_json != '' OR message LIKE '%ORDER%')");
        if ($cntRes && $cRow = $cntRes->fetch_assoc()) {
            $orderCount = (int)$cRow['total_orders'];
        }
        $order_id = "#DM-" . (1001 + $orderCount);
    }

    // Replace #DM-1001 in message text if dynamic order_id is higher
    if (strpos($message, '#DM-1001') !== false && $order_id !== '#DM-1001') {
        $message = str_replace('#DM-1001', $order_id, $message);
    }

    $order_status = "Pending";
    $logs_json = json_encode(array());

    $colCheck = $conn->query("SHOW COLUMNS FROM messages LIKE 'logs_json'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN logs_json TEXT DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, logs_json, sender_type, is_read, payment_status, delivery_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 'unpaid', 'pending')");
    if ($stmt) {
        $stmt->bind_param("ssssssss", $seller_username, $customer_mobile, $message, $items_json, $order_id, $order_status, $logs_json, $sender_type);
        if ($stmt->execute()) {
            // Also write backup row into customer_orders table for Seller & Customer dashboards
            @$conn->query("CREATE TABLE IF NOT EXISTS customer_orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_number VARCHAR(50) NOT NULL,
                seller_username VARCHAR(100) NOT NULL,
                seller_name VARCHAR(255) DEFAULT NULL,
                customer_mobile VARCHAR(20) NOT NULL,
                customer_name VARCHAR(255) DEFAULT NULL,
                items_json LONGTEXT NOT NULL,
                total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
                total_count INT NOT NULL DEFAULT 0,
                order_status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(customer_mobile),
                INDEX(seller_username)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

            @$conn->query("INSERT INTO customer_orders (order_number, seller_username, customer_mobile, customer_name, items_json, total_amount, total_count, order_status) VALUES ('$order_id', '$escapedSeller', '$customer_mobile', 'Customer', '" . $conn->real_escape_string($items_json) . "', 0.00, 1, 'PENDING')");

            echo json_encode(["success" => true, "message" => "Message sent", "order_id" => $order_id]);
            exit();
        }
    }

    $stmtFallback = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, sender_type, is_read, payment_status, delivery_status) VALUES (?, ?, ?, ?, 0, 'unpaid', 'pending')");
    if ($stmtFallback) {
        $stmtFallback->bind_param("ssss", $seller_username, $customer_mobile, $message, $sender_type);
        if ($stmtFallback->execute()) {
            echo json_encode(["success" => true, "message" => "Message sent (fallback)", "order_id" => $order_id]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "SQL Error"]);
    exit();
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
    $cancelled_at = isset($input['cancelled_at']) ? trim($input['cancelled_at']) : date('d/m/Y, H:i');
    $cancel_reason = isset($input['cancel_reason']) ? trim($input['cancel_reason']) : '';

    if ($msg_id > 0) {
        $msgRow = $conn->query("SELECT order_id FROM messages WHERE id = $msg_id LIMIT 1");
        $ordNum = ($msgRow && $r = $msgRow->fetch_assoc()) ? $r['order_id'] : "#DM-" . (1000 + $msg_id);

        if (!empty($cancel_reason) || strtolower($status_text) == 'cancelled') {
            $stmt = $conn->prepare("UPDATE messages SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = ?, cancel_reason = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $cancelled_at, $cancel_reason, $msg_id);
                $stmt->execute();
            }
            @$conn->query("UPDATE customer_orders SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = '$cancelled_at', cancel_reason = '" . $conn->real_escape_string($cancel_reason) . "' WHERE order_number = '$ordNum' OR id = $msg_id");
        } else {
            $stmt = $conn->prepare("UPDATE messages SET order_status = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("si", $status_text, $msg_id);
                $stmt->execute();
            }
            @$conn->query("UPDATE customer_orders SET order_status = '" . $conn->real_escape_string($status_text) . "' WHERE order_number = '$ordNum' OR id = $msg_id");
        }
    }
    echo json_encode(["success" => true]);
    exit();
} elseif ($action == 'update-order-amount') {
    $msg_id = isset($input['message_id']) ? (int)$input['message_id'] : 0;
    $amount = isset($input['order_amount']) ? (float)$input['order_amount'] : (isset($input['amount']) ? (float)$input['amount'] : 0.0);

    $colCheckAmt = $conn->query("SHOW COLUMNS FROM messages LIKE 'order_amount'");
    if (!$colCheckAmt || $colCheckAmt->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN order_amount DECIMAL(10,2) DEFAULT 0.00");
    }

    if ($msg_id > 0) {
        $stmt = $conn->prepare("UPDATE messages SET order_amount = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("di", $amount, $msg_id);
            $stmt->execute();
        }
        $msgRow = $conn->query("SELECT order_id FROM messages WHERE id = $msg_id LIMIT 1");
        $ordNum = ($msgRow && $r = $msgRow->fetch_assoc()) ? $r['order_id'] : "#DM-" . (1000 + $msg_id);
        @$conn->query("UPDATE customer_orders SET total_amount = $amount WHERE order_number = '$ordNum' OR id = $msg_id");
    }
    echo json_encode(["success" => true, "order_amount" => $amount]);
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
        $msgRow = $conn->query("SELECT order_id FROM messages WHERE id = $msg_id LIMIT 1");
        $ordNum = ($msgRow && $r = $msgRow->fetch_assoc()) ? $r['order_id'] : "#DM-" . (1000 + $msg_id);
        @$conn->query("UPDATE customer_orders SET payment_status = '" . $conn->real_escape_string($payment_status) . "', payment_utr = '" . $conn->real_escape_string($payment_utr) . "', paid_amount = $paid_amount, paid_at = '$paid_at' WHERE order_number = '$ordNum' OR id = $msg_id");
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
} elseif ($action == 'place-order') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $customer_mobile = isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '';
    $customer_name = isset($input['customer_name']) ? trim($input['customer_name']) : 'Customer';
    $seller_name = isset($input['seller_name']) ? trim($input['seller_name']) : '';
    $items = isset($input['items']) ? $input['items'] : array();
    $total_amount = isset($input['total_amount']) ? (float)$input['total_amount'] : 0.0;
    $total_count = isset($input['total_count']) ? (int)$input['total_count'] : (is_array($items) ? count($items) : 0);

    if (empty($seller_username) || empty($customer_mobile)) {
        echo json_encode(["success" => false, "message" => "Required fields missing"]);
        exit();
    }

    $items_json = json_encode($items);
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedSeller = $conn->real_escape_string($seller_username);

    // Build message summary string
    $msgText = "🛒 NEW ORDER PLACED\nTotal Items: $total_count\nTotal Amount: ₹" . number_format($total_amount, 2);
    if (is_array($items) && count($items) > 0) {
        $msgLines = array();
        $idx = 1;
        foreach ($items as $it) {
            if (is_array($it)) {
                $iName = isset($it['name']) ? $it['name'] : 'Item';
                $iQty = isset($it['qty']) ? (int)$it['qty'] : 1;
                $iUnit = isset($it['unit']) ? $it['unit'] : 'Pcs';
                $iAmt = isset($it['amount']) ? (float)$it['amount'] : (isset($it['rate']) ? (float)$it['rate'] * $iQty : 0.0);
                $msgLines[] = "$idx. $iName ($iQty $iUnit) - ₹" . number_format($iAmt, 2);
                $idx++;
            }
        }
        if (count($msgLines) > 0) {
            $msgText = implode("\n", $msgLines);
        }
    }

    // Insert directly into messages table (The primary orders table in phpMyAdmin)
    $stmtMsg = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, order_amount, sender_type, is_read, payment_status, delivery_status) VALUES (?, ?, ?, ?, 'TEMP', 'Pending', ?, 'customer', 0, 'unpaid', 'pending')");
    if ($stmtMsg) {
        $stmtMsg->bind_param("ssssd", $seller_username, $customer_mobile, $msgText, $items_json, $total_amount);
        if ($stmtMsg->execute()) {
            $dbInsertId = $stmtMsg->insert_id;
            $orderNumber = "#DM-" . (1000 + $dbInsertId);
            $conn->query("UPDATE messages SET order_id = '$orderNumber' WHERE id = $dbInsertId");

            // Optional backup in customer_orders table
            @$conn->query("CREATE TABLE IF NOT EXISTS customer_orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                order_number VARCHAR(50) NOT NULL,
                seller_username VARCHAR(100) NOT NULL,
                seller_name VARCHAR(255) DEFAULT NULL,
                customer_mobile VARCHAR(20) NOT NULL,
                customer_name VARCHAR(255) DEFAULT NULL,
                items_json LONGTEXT NOT NULL,
                total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
                total_count INT NOT NULL DEFAULT 0,
                order_status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(customer_mobile),
                INDEX(seller_username)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

            @$conn->query("INSERT INTO customer_orders (order_number, seller_username, seller_name, customer_mobile, customer_name, items_json, total_amount, total_count, order_status) VALUES ('$orderNumber', '$escapedSeller', '" . $conn->real_escape_string($seller_name) . "', '$customer_mobile', '" . $conn->real_escape_string($customer_name) . "', '" . $conn->real_escape_string($items_json) . "', $total_amount, $total_count, 'PENDING')");

            echo json_encode([
                "success" => true,
                "message" => "Order saved directly in MySQL Database messages table!",
                "order" => [
                    "id" => $dbInsertId,
                    "order_id" => $orderNumber,
                    "order_number" => $orderNumber,
                    "seller_username" => $seller_username,
                    "seller_name" => !empty($seller_name) ? $seller_name : $seller_username,
                    "customer_mobile" => $customer_mobile,
                    "customer_name" => $customer_name,
                    "items" => $items,
                    "total_amount" => $total_amount,
                    "total_count" => $total_count,
                    "status" => "PENDING",
                    "date" => date('d/m/Y H:i'),
                    "timestamp" => time() * 1000
                ]
            ]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "Failed to write order to MySQL Database"]);
    exit();
} elseif ($action == 'get-seller-customer-orders') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "orders" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $query = "SELECT m.*, c.name as customer_name FROM messages m LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) WHERE (m.seller_username = '$escapedSeller' OR LOWER(m.seller_username) = LOWER('$escapedSeller') OR m.seller_username LIKE '%$escapedSeller%') AND (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%') ORDER BY m.id DESC";

    $res = $conn->query($query);
    $orders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['customer_name'] = !empty($row['customer_name']) ? $row['customer_name'] : "Customer ({$row['customer_mobile']})";
            $orders[] = $row;
        }
    }
    echo json_encode(["success" => true, "orders" => $orders]);
    exit();
} elseif ($action == 'get-all-admin-orders') {
    $query = "SELECT m.*, c.name as customer_name, s.name as seller_name, s.location as seller_location FROM messages m LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) LEFT JOIN sellers s ON (m.seller_username = s.username OR LOWER(m.seller_username) = LOWER(s.username)) WHERE (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%') ORDER BY m.id DESC";

    $res = $conn->query($query);
    $orders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['customer_name'] = !empty($row['customer_name']) ? $row['customer_name'] : "Customer ({$row['customer_mobile']})";
            $row['seller_name'] = !empty($row['seller_name']) ? $row['seller_name'] : $row['seller_username'];
            $orders[] = $row;
        }
    }
    echo json_encode(["success" => true, "orders" => $orders]);
    exit();
} elseif ($action == 'get-customer-orders') {
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : (isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '');

    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $orders = array();

    // 1. Primary Query directly from messages table (phpMyAdmin database table)
    $msgQuery = !empty($last10)
        ? "SELECT m.*, c.name as customer_name, s.name as seller_name FROM messages m LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) LEFT JOIN sellers s ON (m.seller_username = s.username OR LOWER(m.seller_username) = LOWER(s.username)) WHERE (m.customer_mobile = '$customer_mobile' OR m.customer_mobile LIKE '$escapedLike' OR m.customer_mobile LIKE '%$last10%') AND (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%') ORDER BY m.id DESC"
        : "SELECT m.*, c.name as customer_name, s.name as seller_name FROM messages m LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) LEFT JOIN sellers s ON (m.seller_username = s.username OR LOWER(m.seller_username) = LOWER(s.username)) WHERE (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%') ORDER BY m.id DESC LIMIT 50";

    $resMsg = $conn->query($msgQuery);
    if ($resMsg && $resMsg !== true) {
        while ($row = $resMsg->fetch_assoc()) {
            $itemsDecoded = json_decode($row['items_json'], true);
            if (!is_array($itemsDecoded)) $itemsDecoded = array();

            $orderIdStr = !empty($row['order_id']) && $row['order_id'] !== 'Status' ? $row['order_id'] : ("#DM-" . (1000 + (int)$row['id']));

            $alreadyInList = false;
            foreach ($orders as $o) {
                if ($o['order_id'] == $orderIdStr || $o['id'] == (int)$row['id']) {
                    $alreadyInList = true;
                    break;
                }
            }

            if (!$alreadyInList) {
                $sellerU = $row['seller_username'];
                $sName = $sellerU;
                $sRes = $conn->query("SELECT name FROM sellers WHERE username = '$sellerU' OR name = '$sellerU' LIMIT 1");
                if ($sRes && $sRow = $sRes->fetch_assoc()) {
                    if (!empty($sRow['name'])) $sName = $sRow['name'];
                }

                $totAmt = isset($row['order_amount']) ? (float)$row['order_amount'] : 0.0;
                if ($totAmt <= 0) {
                    foreach ($itemsDecoded as $it) {
                        if (is_array($it)) {
                            $itAmt = isset($it['amount']) ? (float)$it['amount'] : ((isset($it['rate']) ? (float)$it['rate'] : 0.0) * (isset($it['qty']) ? (int)$it['qty'] : 1));
                            $totAmt += $itAmt;
                        }
                    }
                }

                $statusStr = !empty($row['order_status']) && $row['order_status'] !== 'Status' ? $row['order_status'] : (!empty($row['delivery_status']) ? $row['delivery_status'] : 'Pending');

                $orders[] = array(
                    "id" => (int)$row['id'],
                    "order_id" => $orderIdStr,
                    "order_number" => $orderIdStr,
                    "seller_username" => $sellerU,
                    "seller_name" => $sName,
                    "customer_mobile" => $row['customer_mobile'],
                    "customer_name" => "Customer",
                    "items" => $itemsDecoded,
                    "total_amount" => $totAmt,
                    "total_count" => count($itemsDecoded),
                    "status" => strtoupper($statusStr),
                    "date" => isset($row['created_at']) ? date('d/m/Y H:i', strtotime($row['created_at'])) : date('d/m/Y H:i'),
                    "timestamp" => isset($row['created_at']) ? strtotime($row['created_at']) * 1000 : time() * 1000
                );
            }
        }
    }

    // 2. Also query customer_orders if table exists
    $checkTable = $conn->query("SHOW TABLES LIKE 'customer_orders'");
    if ($checkTable && $checkTable->num_rows > 0) {
        $orderQuery = !empty($last10) ? "SELECT * FROM customer_orders WHERE customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$escapedLike' ORDER BY id DESC" : "SELECT * FROM customer_orders ORDER BY id DESC LIMIT 50";
        $res = $conn->query($orderQuery);
        if ($res && $res !== true) {
            while ($row = $res->fetch_assoc()) {
                $itemsDecoded = json_decode($row['items_json'], true);
                if (!is_array($itemsDecoded)) $itemsDecoded = array();

                $orderIdStr = $row['order_number'];
                $alreadyInList = false;
                foreach ($orders as $o) {
                    if ($o['order_id'] == $orderIdStr) {
                        $alreadyInList = true;
                        break;
                    }
                }

                if (!$alreadyInList) {
                    $orders[] = array(
                        "id" => (int)$row['id'],
                        "order_id" => $row['order_number'],
                        "order_number" => $row['order_number'],
                        "seller_username" => $row['seller_username'],
                        "seller_name" => !empty($row['seller_name']) ? $row['seller_name'] : $row['seller_username'],
                        "customer_mobile" => $row['customer_mobile'],
                        "customer_name" => $row['customer_name'],
                        "items" => $itemsDecoded,
                        "total_amount" => (float)$row['total_amount'],
                        "total_count" => (int)$row['total_count'],
                        "status" => strtoupper($row['order_status']),
                        "date" => date('d/m/Y H:i', strtotime($row['created_at'])),
                        "timestamp" => strtotime($row['created_at']) * 1000
                    );
                }
            }
        }
    }

    echo json_encode(["success" => true, "orders" => $orders]);
    exit();
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
    $searchLike = "%" . $conn->real_escape_string($last10) . "%";
    $escapedSeller = $conn->real_escape_string($seller_username);

    $query = "SELECT * FROM messages ORDER BY id ASC LIMIT 50";
    if (!empty($seller_username) && !empty($last10)) {
        $query = "SELECT * FROM messages WHERE (seller_username = '$escapedSeller' OR seller_username LIKE '%$escapedSeller%') AND (customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$searchLike') ORDER BY id ASC";
    } elseif (!empty($last10)) {
        $query = "SELECT * FROM messages WHERE customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$searchLike' ORDER BY id ASC";
    } elseif (!empty($seller_username)) {
        $query = "SELECT * FROM messages WHERE seller_username = '$escapedSeller' OR seller_username LIKE '%$escapedSeller%' ORDER BY id ASC LIMIT 50";
    }

    $res = $conn->query($query);
    $messages = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $messages[] = $row;
        }
    }
    echo json_encode(["success" => true, "messages" => $messages]);
    exit();
} elseif ($action == 'delete-seller') {
    $username = isset($input['username']) ? trim($input['username']) : '';
    $stmt = $conn->prepare("DELETE FROM sellers WHERE username = ?");
    if ($stmt) {
        $stmt->bind_param("s", $username);
        $stmt->execute();
    }
    echo json_encode(["success" => true, "message" => "Seller Deleted"]);
} elseif ($action == 'seller-login' || $action == 'login-seller') {
    $username = isset($input['username']) ? trim($input['username']) : (isset($_GET['username']) ? trim($_GET['username']) : '');
    $password = isset($input['password']) ? trim($input['password']) : (isset($_GET['password']) ? trim($_GET['password']) : '');

    $escapedUser = $conn->real_escape_string($username);

    $digits = preg_replace('/[^0-9]/', '', $username);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    $query = "SELECT * FROM sellers WHERE (LOWER(username) = LOWER('$escapedUser') OR LOWER(name) = LOWER('$escapedUser')" . (!empty($last10) ? " OR mobile = '$username' OR mobile LIKE '$escapedLike'" : "") . ") ORDER BY id DESC LIMIT 1";

    $res = $conn->query($query);
    if ($res && $row = $res->fetch_assoc()) {
        $dbPass = trim($row['password'] ?? '');
        $passMatch = ($dbPass === $password) || (strtolower($dbPass) === strtolower($password));
        if ($passMatch) {
            echo json_encode(["success" => true, "seller" => $row]);
            exit();
        } else {
            echo json_encode(["success" => false, "message" => "Incorrect Password"]);
            exit();
        }
    }

    echo json_encode(["success" => false, "message" => "Invalid credentials"]);
    exit();
} elseif ($action == 'add-seller-product') {
    $colCheckBtnText = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'button_text'");
    if (!$colCheckBtnText || $colCheckBtnText->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN button_text VARCHAR(100) DEFAULT 'Buy Now'");
    }

    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $category = isset($input['category']) ? trim($input['category']) : '';
    $section = isset($input['section']) ? trim($input['section']) : '';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;
    $button_text = isset($input['button_text']) && !empty(trim($input['button_text'])) ? trim($input['button_text']) : 'Buy Now';

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and product name are required"]);
        exit();
    }

    $colCheckCat = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'category'");
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : (isset($input['image']) ? trim($input['image']) : '');

    $colCheckProdImg = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'image_url'");
    if (!$colCheckProdImg || $colCheckProdImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN image_url LONGTEXT DEFAULT NULL");
    }

    $colCheckProdSec = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'section'");
    if (!$colCheckProdSec || $colCheckProdSec->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN section VARCHAR(255) DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO seller_products (seller_username, name, description, unit, category, section, qty, rate, image_url, button_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("sssssidsss", $seller_username, $name, $description, $unit, $category, $section, $qty, $rate, $image_url, $button_text);
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
                    "category" => $category,
                    "section" => $section,
                    "qty" => $qty,
                    "rate" => $rate,
                    "image_url" => $image_url,
                    "button_text" => $button_text
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add product"]);
    exit();
} elseif ($action == 'get-seller-products') {
    $colCheckBtnText = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'button_text'");
    if (!$colCheckBtnText || $colCheckBtnText->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN button_text VARCHAR(100) DEFAULT 'Buy Now'");
    }

    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    $escapedSeller = $conn->real_escape_string($seller_username);

    $query = !empty($seller_username)
        ? "SELECT * FROM seller_products WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') OR seller_username LIKE '%$escapedSeller%' OR seller_username IS NULL OR seller_username = '' ORDER BY id DESC"
        : "SELECT * FROM seller_products ORDER BY id DESC";

    $res = $conn->query($query);
    $products = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['qty'] = isset($row['qty']) ? (int)$row['qty'] : 1;
            $row['rate'] = (float)$row['rate'];
            $row['section'] = isset($row['section']) ? $row['section'] : '';
            $row['image_url'] = isset($row['image_url']) ? $row['image_url'] : (isset($row['image']) ? $row['image'] : '');
            $row['button_text'] = isset($row['button_text']) && !empty($row['button_text']) ? $row['button_text'] : 'Buy Now';
            $products[] = $row;
        }
    }
    // Fallback if specific seller match had 0 rows: return all products from DB
    if (empty($products)) {
        $resAll = $conn->query("SELECT * FROM seller_products ORDER BY id DESC");
        if ($resAll && $resAll !== true) {
            while ($row = $resAll->fetch_assoc()) {
                $row['id'] = (int)$row['id'];
                $row['qty'] = isset($row['qty']) ? (int)$row['qty'] : 1;
                $row['rate'] = (float)$row['rate'];
                $row['section'] = isset($row['section']) ? $row['section'] : '';
                $row['image_url'] = isset($row['image_url']) ? $row['image_url'] : (isset($row['image']) ? $row['image'] : '');
                $row['button_text'] = isset($row['button_text']) && !empty($row['button_text']) ? $row['button_text'] : 'Buy Now';
                $products[] = $row;
            }
        }
    }
    echo json_encode(["success" => true, "products" => $products]);
    exit();
} elseif ($action == 'update-seller-product') {
    $colCheckBtnText = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'button_text'");
    if (!$colCheckBtnText || $colCheckBtnText->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN button_text VARCHAR(100) DEFAULT 'Buy Now'");
    }

    $id = isset($input['id']) ? (int)$input['id'] : 0;
    $name = isset($input['name']) ? trim($input['name']) : '';
    $description = isset($input['description']) ? trim($input['description']) : '';
    $unit = isset($input['unit']) ? trim($input['unit']) : 'Pcs';
    $category = isset($input['category']) ? trim($input['category']) : '';
    $section = isset($input['section']) ? trim($input['section']) : '';
    $qty = isset($input['qty']) ? (int)$input['qty'] : 1;
    if ($qty <= 0) $qty = 1;
    $rate = isset($input['rate']) ? (float)$input['rate'] : 0.0;
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : (isset($input['image']) ? trim($input['image']) : '');
    $button_text = isset($input['button_text']) && !empty(trim($input['button_text'])) ? trim($input['button_text']) : 'Buy Now';

    if ($id <= 0 || empty($name)) {
        echo json_encode(["success" => false, "message" => "Product ID and name required"]);
        exit();
    }

    $stmt = $conn->prepare("UPDATE seller_products SET name = ?, description = ?, unit = ?, category = ?, section = ?, qty = ?, rate = ?, image_url = ?, button_text = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("sssssidssi", $name, $description, $unit, $category, $section, $qty, $rate, $image_url, $button_text, $id);
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
} elseif ($action == 'get-seller-sections') {
    $colCheckSecTextColor = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'text_color'");
    if (!$colCheckSecTextColor || $colCheckSecTextColor->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN text_color VARCHAR(50) DEFAULT '#0F172A'");
    }
    $colCheckSecCols = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'columns'");
    if (!$colCheckSecCols || $colCheckSecCols->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN columns INT DEFAULT 2");
    }

    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "sections" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_sections WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') OR seller_username LIKE '%$escapedSeller%' ORDER BY id ASC");
    $sections = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['text_color'] = isset($row['text_color']) && !empty($row['text_color']) ? $row['text_color'] : '#0F172A';
            $row['columns'] = isset($row['columns']) ? (int)$row['columns'] : 2;
            $sections[] = $row;
        }
    }
    echo json_encode(["success" => true, "sections" => $sections]);
    exit();
} elseif ($action == 'add-seller-section') {
    $colCheckSecTextColor = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'text_color'");
    if (!$colCheckSecTextColor || $colCheckSecTextColor->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN text_color VARCHAR(50) DEFAULT '#0F172A'");
    }
    $colCheckSecCols = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'columns'");
    if (!$colCheckSecCols || $colCheckSecCols->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN columns INT DEFAULT 2");
    }

    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $name = isset($input['name']) ? trim($input['name']) : (isset($_GET['name']) ? trim($_GET['name']) : (isset($_POST['name']) ? trim($_POST['name']) : ''));
    $icon = isset($input['icon']) ? trim($input['icon']) : '🏷️';
    $bg_color = isset($input['bg_color']) ? trim($input['bg_color']) : '#FFFFFF';
    $text_color = isset($input['text_color']) ? trim($input['text_color']) : '#0F172A';
    $columns = isset($input['columns']) ? (int)$input['columns'] : 2;
    if ($columns <= 0 || $columns > 3) $columns = 2;

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and section name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);
    $chk = $conn->query("SELECT id FROM seller_sections WHERE seller_username = '$escapedSeller' AND name = '$escapedName' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        $existingId = (int)$row['id'];
        $stmtUp = $conn->prepare("UPDATE seller_sections SET icon = ?, bg_color = ?, text_color = ?, columns = ? WHERE id = ?");
        if ($stmtUp) {
            $stmtUp->bind_param("sssii", $icon, $bg_color, $text_color, $columns, $existingId);
            $stmtUp->execute();
        }
        echo json_encode([
            "success" => true,
            "message" => "Section updated",
            "section" => [
                "id" => $existingId,
                "seller_username" => $seller_username,
                "name" => $name,
                "icon" => $icon,
                "bg_color" => $bg_color,
                "text_color" => $text_color,
                "columns" => $columns
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_sections (seller_username, name, icon, bg_color, text_color, columns) VALUES (?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("sssssi", $seller_username, $name, $icon, $bg_color, $text_color, $columns);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Section added",
                "section" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "icon" => $icon,
                    "bg_color" => $bg_color,
                    "text_color" => $text_color,
                    "columns" => $columns
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add section"]);
    exit();
} elseif ($action == 'update-seller-section') {
    $colCheckSecTextColor = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'text_color'");
    if (!$colCheckSecTextColor || $colCheckSecTextColor->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN text_color VARCHAR(50) DEFAULT '#0F172A'");
    }
    $colCheckSecCols = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'columns'");
    if (!$colCheckSecCols || $colCheckSecCols->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN columns INT DEFAULT 2");
    }

    $id = isset($input['id']) ? (int)$input['id'] : (isset($_POST['id']) ? (int)$_POST['id'] : 0);
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $name = isset($input['name']) ? trim($input['name']) : (isset($_POST['name']) ? trim($_POST['name']) : '');
    $icon = isset($input['icon']) ? trim($input['icon']) : '🏷️';
    $bg_color = isset($input['bg_color']) ? trim($input['bg_color']) : '#FFFFFF';
    $text_color = isset($input['text_color']) ? trim($input['text_color']) : '#0F172A';
    $columns = isset($input['columns']) ? (int)$input['columns'] : 2;
    if ($columns <= 0 || $columns > 3) $columns = 2;

    if (empty($name)) {
        echo json_encode(["success" => false, "message" => "Section name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);

    $updated = false;
    if ($id > 0) {
        $stmt = $conn->prepare("UPDATE seller_sections SET name = ?, icon = ?, bg_color = ?, text_color = ?, columns = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssssii", $name, $icon, $bg_color, $text_color, $columns, $id);
            if ($stmt->execute() && $stmt->affected_rows > 0) {
                $updated = true;
            }
        }
    }

    if (!$updated && !empty($seller_username)) {
        $stmt = $conn->prepare("UPDATE seller_sections SET icon = ?, bg_color = ?, text_color = ?, columns = ? WHERE seller_username = ? AND name = ?");
        if ($stmt) {
            $stmt->bind_param("sssiss", $icon, $bg_color, $text_color, $columns, $seller_username, $name);
            if ($stmt->execute() && $stmt->affected_rows > 0) {
                $updated = true;
            }
        }
    }

    if (!$updated && !empty($seller_username)) {
        $stmtIns = $conn->prepare("INSERT INTO seller_sections (seller_username, name, icon, bg_color, text_color, columns) VALUES (?, ?, ?, ?, ?, ?)");
        if ($stmtIns) {
            $stmtIns->bind_param("sssssi", $seller_username, $name, $icon, $bg_color, $text_color, $columns);
            $stmtIns->execute();
        }
    }

    echo json_encode(["success" => true, "message" => "Section updated", "columns" => $columns]);
    exit();
} elseif ($action == 'delete-seller-section') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_sections WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Section deleted"]);
    exit();
} elseif ($action == 'get-seller-units') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username)) {
        echo json_encode(["success" => true, "units" => array()]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $res = $conn->query("SELECT * FROM seller_units WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') OR seller_username LIKE '%$escapedSeller%' ORDER BY id ASC");
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
} elseif ($action == 'get-seller-categories') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    $escapedSeller = $conn->real_escape_string($seller_username);

    $query = !empty($seller_username)
        ? "SELECT * FROM seller_categories WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') OR seller_username LIKE '%$escapedSeller%' OR seller_username IS NULL OR seller_username = '' ORDER BY id ASC"
        : "SELECT * FROM seller_categories ORDER BY id ASC";

    $res = $conn->query($query);
    $categories = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $categories[] = $row;
        }
    }
    // Fallback if specific seller match had 0 rows: return all categories from DB
    if (empty($categories)) {
        $resAll = $conn->query("SELECT * FROM seller_categories ORDER BY id ASC");
        if ($resAll && $resAll !== true) {
            while ($row = $resAll->fetch_assoc()) {
                $row['id'] = (int)$row['id'];
                $categories[] = $row;
            }
        }
    }
    echo json_encode(["success" => true, "categories" => $categories]);
    exit();
} elseif ($action == 'add-seller-category') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : '';
    $color = isset($input['color']) ? trim($input['color']) : '#8B5CF6';

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and category name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);
    $chk = $conn->query("SELECT id, image_url, color FROM seller_categories WHERE seller_username = '$escapedSeller' AND name = '$escapedName' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        $cId = (int)$row['id'];
        if (!empty($image_url)) {
            $upStmt = $conn->prepare("UPDATE seller_categories SET color = ?, image_url = ? WHERE id = ?");
            if ($upStmt) {
                $upStmt->bind_param("ssi", $color, $image_url, $cId);
                $upStmt->execute();
            }
        } else {
            $upStmt = $conn->prepare("UPDATE seller_categories SET color = ? WHERE id = ?");
            if ($upStmt) {
                $upStmt->bind_param("si", $color, $cId);
                $upStmt->execute();
            }
        }

        echo json_encode([
            "success" => true,
            "message" => "Category color updated in database",
            "category" => [
                "id" => $cId,
                "seller_username" => $seller_username,
                "name" => $name,
                "image_url" => !empty($image_url) ? $image_url : $row['image_url'],
                "color" => $color
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_categories (seller_username, name, image_url, color) VALUES (?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssss", $seller_username, $name, $image_url, $color);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Category added",
                "category" => [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "image_url" => $image_url,
                    "color" => $color
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add category"]);
    exit();
} elseif ($action == 'update-seller-category') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    $name = isset($input['name']) ? trim($input['name']) : (isset($_GET['name']) ? trim($_GET['name']) : '');
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : '';
    $color = isset($input['color']) ? trim($input['color']) : '#8B5CF6';

    if (empty($name)) {
        echo json_encode(["success" => false, "message" => "Category name required"]);
        exit();
    }

    $updated = false;

    // 1. Update by ID if ID > 0
    if ($id > 0) {
        if (!empty($image_url)) {
            $stmt = $conn->prepare("UPDATE seller_categories SET name = ?, image_url = ?, color = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("sssi", $name, $image_url, $color, $id);
                if ($stmt->execute() && $stmt->affected_rows > 0) $updated = true;
            }
        } else {
            $stmt = $conn->prepare("UPDATE seller_categories SET name = ?, color = ? WHERE id = ?");
            if ($stmt) {
                $stmt->bind_param("ssi", $name, $color, $id);
                if ($stmt->execute() && $stmt->affected_rows > 0) $updated = true;
            }
        }
    }

    // 2. Fallback update by seller_username & name
    if (!empty($seller_username)) {
        if (!empty($image_url)) {
            $stmt2 = $conn->prepare("UPDATE seller_categories SET color = ?, image_url = ? WHERE seller_username = ? AND name = ?");
            if ($stmt2) {
                $stmt2->bind_param("ssss", $color, $image_url, $seller_username, $name);
                if ($stmt2->execute() && $stmt2->affected_rows > 0) $updated = true;
            }
        } else {
            $stmt2 = $conn->prepare("UPDATE seller_categories SET color = ? WHERE seller_username = ? AND name = ?");
            if ($stmt2) {
                $stmt2->bind_param("sss", $color, $seller_username, $name);
                if ($stmt2->execute() && $stmt2->affected_rows > 0) $updated = true;
            }
        }
    } else {
        // Fallback update by name only
        if (!empty($image_url)) {
            $stmt3 = $conn->prepare("UPDATE seller_categories SET color = ?, image_url = ? WHERE name = ?");
            if ($stmt3) {
                $stmt3->bind_param("sss", $color, $image_url, $name);
                if ($stmt3->execute() && $stmt3->affected_rows > 0) $updated = true;
            }
        } else {
            $stmt3 = $conn->prepare("UPDATE seller_categories SET color = ? WHERE name = ?");
            if ($stmt3) {
                $stmt3->bind_param("ss", $color, $name);
                if ($stmt3->execute() && $stmt3->affected_rows > 0) $updated = true;
            }
        }
    }

    echo json_encode(["success" => true, "message" => "Category color updated in database", "color" => $color, "updated" => $updated]);
    exit();
} elseif ($action == 'delete-seller-category') {
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_GET['id']) ? (int)$_GET['id'] : 0);
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $name = isset($input['name']) ? trim($input['name']) : '';

    if ($id > 0) {
        $stmt = $conn->prepare("DELETE FROM seller_categories WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("i", $id);
            $stmt->execute();
        }
    } elseif (!empty($seller_username) && !empty($name)) {
        $stmt = $conn->prepare("DELETE FROM seller_categories WHERE seller_username = ? AND name = ?");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $name);
            $stmt->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Category deleted"]);
    exit();
} else {
    echo json_encode(["success" => true, "message" => "Daily Mart API Active"]);
}

$conn->close();
?>
