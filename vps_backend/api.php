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

$colCheckSliderFullWidth = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'full_width'");
if (!$colCheckSliderFullWidth || $colCheckSliderFullWidth->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sliders ADD COLUMN full_width INT DEFAULT 0");
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

$colCheckBorder = $conn->query("SHOW COLUMNS FROM sellers LIKE 'border_image'");
if (!$colCheckBorder || $colCheckBorder->num_rows == 0) {
    @$conn->query("ALTER TABLE sellers ADD COLUMN border_image LONGTEXT DEFAULT NULL");
}

// Auto-check & create seller_borders table in database
@$conn->query("CREATE TABLE IF NOT EXISTS seller_borders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL UNIQUE,
    border_image LONGTEXT DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckAnim = $conn->query("SHOW COLUMNS FROM sellers LIKE 'header_animations'");
if (!$colCheckAnim || $colCheckAnim->num_rows == 0) {
    @$conn->query("ALTER TABLE sellers ADD COLUMN header_animations LONGTEXT DEFAULT NULL");
}

// Auto-check & create seller_animations table in database
@$conn->query("CREATE TABLE IF NOT EXISTS seller_animations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    seller_username VARCHAR(100) NOT NULL UNIQUE,
    header_animations LONGTEXT DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

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
    icon_url LONGTEXT DEFAULT NULL,
    poster_url LONGTEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(seller_username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

$colCheckCatIcon = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'icon_url'");
if (!$colCheckCatIcon || $colCheckCatIcon->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN icon_url LONGTEXT DEFAULT NULL");
}

$colCheckCatColor = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'color'");
if (!$colCheckCatColor || $colCheckCatColor->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN color VARCHAR(50) DEFAULT '#8B5CF6'");
}

$colCheckCatPoster = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'poster_url'");
if (!$colCheckCatPoster || $colCheckCatPoster->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN poster_url LONGTEXT DEFAULT NULL");
}

$colCheckCatItemBg = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'item_bg_color'");
if (!$colCheckCatItemBg || $colCheckCatItemBg->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN item_bg_color VARCHAR(50) DEFAULT '#F8FAFC'");
}

$colCheckCatSections = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'sections'");
if (!$colCheckCatSections || $colCheckCatSections->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN sections TEXT DEFAULT NULL");
}

$colCheckCatHideName = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'hide_name'");
if (!$colCheckCatHideName || $colCheckCatHideName->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN hide_name TINYINT(1) DEFAULT 0");
}

$colCheckCatFullSize = $conn->query("SHOW COLUMNS FROM seller_categories LIKE 'full_size_image'");
if (!$colCheckCatFullSize || $colCheckCatFullSize->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_categories ADD COLUMN full_size_image TINYINT(1) DEFAULT 0");
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

$colCheckSecFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'full_width'");
if (!$colCheckSecFullWidth || $colCheckSecFullWidth->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sections ADD COLUMN full_width INT DEFAULT 0");
}

$colCheckSecPosterFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'poster_full_width'");
if (!$colCheckSecPosterFullWidth || $colCheckSecPosterFullWidth->num_rows == 0) {
    @$conn->query("ALTER TABLE seller_sections ADD COLUMN poster_full_width INT DEFAULT 0");
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

        $chkRes = $conn->query("SELECT name, address_json, is_blocked, blocked_reason FROM customers WHERE mobile = '$mobile' OR mobile LIKE '$escapedLike' ORDER BY id DESC LIMIT 1");
        if ($chkRes && $chkRow = $chkRes->fetch_assoc()) {
            if (!empty($chkRow['is_blocked']) && (int)$chkRow['is_blocked'] === 1) {
                $bReason = trim($chkRow['blocked_reason'] ?? '');
                echo json_encode([
                    "success" => false,
                    "is_blocked" => true,
                    "role" => "customer",
                    "mobile" => $mobile,
                    "name" => trim($chkRow['name'] ?? 'Customer'),
                    "message" => "आपकी ID ब्लॉक कर दी गई है। सहायता के लिए कृपया हमारी सपोर्ट टीम से संपर्क करें。"
                ]);
                exit();
            }
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
            $row['full_width'] = isset($row['full_width']) ? (int)$row['full_width'] : 0;
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
    $full_width = isset($input['full_width']) ? (int)$input['full_width'] : (isset($_POST['full_width']) ? (int)$_POST['full_width'] : 0);
    if ($full_width != 1) $full_width = 0;

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

    $colCheckSliderFullWidth = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'full_width'");
    if (!$colCheckSliderFullWidth || $colCheckSliderFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN full_width INT DEFAULT 0");
    }

    $stmt = $conn->prepare("INSERT INTO seller_sliders (seller_username, tag, title, description, bg_image_url, tag_bg_color, tag_shape, title_color, desc_color, section, position, overlay_dim, remove_white_bg, img_fit, full_width) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssssssssssdisii", $seller_username, $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color, $section, $position, $overlay_dim, $remove_white_bg, $img_fit, $full_width);
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
                    "full_width" => $full_width,
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
    $full_width = isset($input['full_width']) ? (int)$input['full_width'] : (isset($_POST['full_width']) ? (int)$_POST['full_width'] : 0);
    if ($full_width != 1) $full_width = 0;

    $colCheckSec = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'section'");
    if (!$colCheckSec || $colCheckSec->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN section VARCHAR(255) DEFAULT 'Top Banner'");
    }

    $colCheckPos = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'position'");
    if (!$colCheckPos || $colCheckPos->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN position VARCHAR(50) DEFAULT 'internal'");
    }

    $colCheckSliderFullWidth = $conn->query("SHOW COLUMNS FROM seller_sliders LIKE 'full_width'");
    if (!$colCheckSliderFullWidth || $colCheckSliderFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sliders ADD COLUMN full_width INT DEFAULT 0");
    }

    if ($slider_id > 0) {
        $stmt = $conn->prepare("UPDATE seller_sliders SET tag = ?, title = ?, description = ?, bg_image_url = ?, tag_bg_color = ?, tag_shape = ?, title_color = ?, desc_color = ?, section = ?, position = ?, overlay_dim = ?, remove_white_bg = ?, img_fit = ?, full_width = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssssssssssdisii", $tag, $title, $description, $bg_image_url, $tag_bg_color, $tag_shape, $title_color, $desc_color, $section, $position, $overlay_dim, $remove_white_bg, $img_fit, $full_width, $slider_id);
            $stmt->execute();
            echo json_encode(["success" => true, "message" => "Slider updated in database", "full_width" => $full_width]);
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
} elseif ($action == 'get-all-customers') {
    // 1. Auto-check & add is_blocked and blocked_reason and created_at columns if missing
    $chkBlocked = $conn->query("SHOW COLUMNS FROM customers LIKE 'is_blocked'");
    if (!$chkBlocked || $chkBlocked->num_rows == 0) {
        @$conn->query("ALTER TABLE customers ADD COLUMN is_blocked TINYINT(1) DEFAULT 0");
    }
    $chkReason = $conn->query("SHOW COLUMNS FROM customers LIKE 'blocked_reason'");
    if (!$chkReason || $chkReason->num_rows == 0) {
        @$conn->query("ALTER TABLE customers ADD COLUMN blocked_reason VARCHAR(255) DEFAULT NULL");
    }
    $chkCreated = $conn->query("SHOW COLUMNS FROM customers LIKE 'created_at'");
    if (!$chkCreated || $chkCreated->num_rows == 0) {
        @$conn->query("ALTER TABLE customers ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
    }

    $res = $conn->query("SELECT * FROM customers ORDER BY id DESC");
    $customers = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $cMobile = trim($row['mobile'] ?? '');
            $digits = preg_replace('/[^0-9]/', '', $cMobile);
            $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

            // Count total orders for this customer from messages table
            $orderCount = 0;
            if (!empty($last10)) {
                $ordRes = $conn->query("SELECT COUNT(*) as total FROM messages WHERE (customer_mobile = '$cMobile' OR customer_mobile LIKE '%$last10%') AND (items_json IS NOT NULL OR order_id IS NOT NULL OR message LIKE '%ORDER%')");
                if ($ordRes && $ordRow = $ordRes->fetch_assoc()) {
                    $orderCount = (int)$ordRow['total'];
                }
            }

            $row['id'] = (int)$row['id'];
            $row['is_blocked'] = isset($row['is_blocked']) ? (int)$row['is_blocked'] : 0;
            $row['total_orders'] = $orderCount;
            $customers[] = $row;
        }
    }

    echo json_encode(["success" => true, "customers" => $customers]);
    exit();
} elseif ($action == 'toggle-block-customer') {
    $mobile = isset($input['mobile']) ? trim($input['mobile']) : (isset($_POST['mobile']) ? trim($_POST['mobile']) : (isset($_GET['mobile']) ? trim($_GET['mobile']) : ''));
    $id = isset($input['id']) ? (int)$input['id'] : (isset($_POST['id']) ? (int)$_POST['id'] : 0);
    $is_blocked = isset($input['is_blocked']) ? (int)$input['is_blocked'] : (isset($_POST['is_blocked']) ? (int)$_POST['is_blocked'] : 1);
    $reason = isset($input['reason']) ? trim($input['reason']) : '';

    if (empty($mobile) && $id <= 0) {
        echo json_encode(["success" => false, "message" => "Customer mobile or id required"]);
        exit();
    }

    $chkBlocked = $conn->query("SHOW COLUMNS FROM customers LIKE 'is_blocked'");
    if (!$chkBlocked || $chkBlocked->num_rows == 0) {
        @$conn->query("ALTER TABLE customers ADD COLUMN is_blocked TINYINT(1) DEFAULT 0");
    }
    $chkReason = $conn->query("SHOW COLUMNS FROM customers LIKE 'blocked_reason'");
    if (!$chkReason || $chkReason->num_rows == 0) {
        @$conn->query("ALTER TABLE customers ADD COLUMN blocked_reason VARCHAR(255) DEFAULT NULL");
    }

    $escapedReason = $conn->real_escape_string($reason);
    if ($id > 0) {
        $conn->query("UPDATE customers SET is_blocked = $is_blocked, blocked_reason = '$escapedReason' WHERE id = $id");
    }
    if (!empty($mobile)) {
        $digits = preg_replace('/[^0-9]/', '', $mobile);
        $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;
        $conn->query("UPDATE customers SET is_blocked = $is_blocked, blocked_reason = '$escapedReason' WHERE mobile = '$mobile' OR mobile LIKE '%$last10%'");
    }

    echo json_encode([
        "success" => true,
        "message" => $is_blocked == 1 ? "Customer has been blocked" : "Customer has been unblocked",
        "is_blocked" => $is_blocked
    ]);
    exit();
} elseif ($action == 'check-customer-blocked-status') {
    $mobile = isset($_GET['mobile']) ? trim($_GET['mobile']) : (isset($input['mobile']) ? trim($input['mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    $chkBlocked = $conn->query("SHOW COLUMNS FROM customers LIKE 'is_blocked'");
    if (!$chkBlocked || $chkBlocked->num_rows == 0) {
        echo json_encode(["success" => true, "is_blocked" => false]);
        exit();
    }

    $isBlocked = false;
    $reason = '';
    if (!empty($last10)) {
        $res = $conn->query("SELECT is_blocked, blocked_reason FROM customers WHERE mobile = '$mobile' OR mobile LIKE '%$last10%' ORDER BY id DESC LIMIT 1");
        if ($res && $row = $res->fetch_assoc()) {
            $isBlocked = ((int)($row['is_blocked'] ?? 0)) === 1;
            $reason = trim($row['blocked_reason'] ?? '');
        }
    }

    echo json_encode([
        "success" => true,
        "is_blocked" => $isBlocked,
        "reason" => $reason
    ]);
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

    $nextId = 0;
    $aiRes = $conn->query("SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'messages'");
    if ($aiRes && $aiRow = $aiRes->fetch_assoc() && !empty($aiRow['AUTO_INCREMENT'])) {
        $nextId = (int)$aiRow['AUTO_INCREMENT'];
    }
    if ($nextId <= 0) {
        $maxRes = $conn->query("SELECT MAX(id) as max_id FROM messages");
        $maxId = 0;
        if ($maxRes && $mRow = $maxRes->fetch_assoc()) {
            $maxId = (int)$mRow['max_id'];
        }
        $nextId = $maxId + 1;
    }

    $nextNum = 1000 + $nextId;
    $nextOrderId = "#DM-" . $nextNum;

    echo json_encode([
        "success" => true,
        "next_order_id" => $nextOrderId,
        "order_number" => $nextOrderId,
        "sequence" => $nextNum,
        "total_orders" => $maxId
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
    $order_id = isset($input['order_id']) ? trim($input['order_id']) : '';
    $status_text = isset($input['order_status']) ? trim($input['order_status']) : 'Ready';
    $cancelled_at = isset($input['cancelled_at']) ? trim($input['cancelled_at']) : date('d/m/Y, H:i');
    $cancel_reason = isset($input['cancel_reason']) ? trim($input['cancel_reason']) : '';

    if (empty($order_id) && $msg_id > 1000) {
        $order_id = "#DM-$msg_id";
    }

    // Resolve real message id in DB:
    $realMsgId = 0;
    if ($msg_id > 0) {
        $check = $conn->query("SELECT id FROM messages WHERE id = $msg_id LIMIT 1");
        if ($check && $r = $check->fetch_assoc()) {
            $realMsgId = (int)$r['id'];
        }
    }
    if ($realMsgId == 0 && !empty($order_id)) {
        $cleanOrd = $conn->real_escape_string($order_id);
        $check = $conn->query("SELECT id FROM messages WHERE order_id = '$cleanOrd' OR order_id LIKE '%$cleanOrd%' LIMIT 1");
        if ($check && $r = $check->fetch_assoc()) {
            $realMsgId = (int)$r['id'];
        }
    }
    if ($realMsgId == 0 && $msg_id > 1000) {
        $possibleDbId = $msg_id - 1000;
        $check = $conn->query("SELECT id FROM messages WHERE id = $possibleDbId LIMIT 1");
        if ($check && $r = $check->fetch_assoc()) {
            $realMsgId = (int)$r['id'];
        }
    }

    if ($realMsgId > 0 || !empty($order_id)) {
        $msgRow = ($realMsgId > 0) ? $conn->query("SELECT order_id FROM messages WHERE id = $realMsgId LIMIT 1") : null;
        $ordNum = ($msgRow && $r = $msgRow->fetch_assoc()) ? $r['order_id'] : (!empty($order_id) ? $order_id : "#DM-" . (1000 + $realMsgId));

        if (!empty($cancel_reason) || strtolower($status_text) == 'cancelled') {
            if ($realMsgId > 0) {
                $stmt = $conn->prepare("UPDATE messages SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = ?, cancel_reason = ? WHERE id = ?");
                if ($stmt) {
                    $stmt->bind_param("ssi", $cancelled_at, $cancel_reason, $realMsgId);
                    $stmt->execute();
                }
            } else if (!empty($order_id)) {
                $stmt = $conn->prepare("UPDATE messages SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = ?, cancel_reason = ? WHERE order_id = ?");
                if ($stmt) {
                    $stmt->bind_param("sss", $cancelled_at, $cancel_reason, $order_id);
                    $stmt->execute();
                }
            }
            @$conn->query("UPDATE customer_orders SET order_status = 'Cancelled', delivery_status = 'Cancelled', cancelled_at = '$cancelled_at', cancel_reason = '" . $conn->real_escape_string($cancel_reason) . "' WHERE order_number = '$ordNum' OR id = $realMsgId");
        } else {
            // Updating to Ready or other status:
            $delivStatus = (strtolower($status_text) == 'ready') ? 'Ready' : $status_text;
            if ($realMsgId > 0) {
                $stmt = $conn->prepare("UPDATE messages SET order_status = ?, delivery_status = ? WHERE id = ?");
                if ($stmt) {
                    $stmt->bind_param("ssi", $status_text, $delivStatus, $realMsgId);
                    $stmt->execute();
                }
            } else if (!empty($order_id)) {
                $stmt = $conn->prepare("UPDATE messages SET order_status = ?, delivery_status = ? WHERE order_id = ?");
                if ($stmt) {
                    $stmt->bind_param("sss", $status_text, $delivStatus, $order_id);
                    $stmt->execute();
                }
            }
            @$conn->query("UPDATE customer_orders SET order_status = '" . $conn->real_escape_string($status_text) . "', delivery_status = '" . $conn->real_escape_string($delivStatus) . "' WHERE order_number = '$ordNum' OR id = $realMsgId");
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

    $payment_mode = isset($input['payment_mode']) && !empty(trim($input['payment_mode'])) ? trim($input['payment_mode']) : 'Cash on Delivery';
    $payment_status = isset($input['payment_status']) && !empty(trim($input['payment_status'])) ? trim($input['payment_status']) : (strtolower($payment_mode) == 'online' ? 'paid' : 'unpaid');
    $payment_utr = isset($input['payment_utr']) ? trim($input['payment_utr']) : (isset($input['utr']) ? trim($input['utr']) : '');
    $paid_amount = isset($input['paid_amount']) ? (float)$input['paid_amount'] : ($payment_status == 'paid' ? $total_amount : 0.0);
    $paid_at = isset($input['paid_at']) && !empty(trim($input['paid_at'])) ? trim($input['paid_at']) : ($payment_status == 'paid' ? date('d/m/Y, H:i') : null);
    $delivery_address = isset($input['delivery_address']) ? trim($input['delivery_address']) : (isset($input['address']) ? trim($input['address']) : '');

    // Build message summary string
    $msgText = "🛒 NEW ORDER PLACED\nTotal Items: $total_count\nTotal Amount: ₹" . number_format($total_amount, 2);
    $msgText .= "\n💳 Payment Mode: $payment_mode (" . strtoupper($payment_status) . ")";
    if (!empty($payment_utr)) {
        $msgText .= "\nTxn/UTR: $payment_utr";
    }
    if (!empty($delivery_address)) {
        $msgText .= "\n📍 Address: $delivery_address";
    }

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
            $msgText .= "\n\nItems:\n" . implode("\n", $msgLines);
        }
    }

    $colCheckPayMode = $conn->query("SHOW COLUMNS FROM messages LIKE 'payment_mode'");
    if (!$colCheckPayMode || $colCheckPayMode->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN payment_mode VARCHAR(50) DEFAULT 'Cash on Delivery'");
    }
    $colCheckDelAddr = $conn->query("SHOW COLUMNS FROM messages LIKE 'delivery_address'");
    if (!$colCheckDelAddr || $colCheckDelAddr->num_rows == 0) {
        @$conn->query("ALTER TABLE messages ADD COLUMN delivery_address TEXT DEFAULT NULL");
    }

    // Insert directly into messages table (The primary orders table in phpMyAdmin)
    $stmtMsg = $conn->prepare("INSERT INTO messages (seller_username, customer_mobile, message, items_json, order_id, order_status, order_amount, sender_type, is_read, payment_status, payment_mode, payment_utr, paid_amount, paid_at, delivery_address, delivery_status) VALUES (?, ?, ?, ?, 'TEMP', 'Pending', ?, 'customer', 0, ?, ?, ?, ?, ?, ?, 'pending')");
    if ($stmtMsg) {
        $stmtMsg->bind_param("ssssdsssdss", $seller_username, $customer_mobile, $msgText, $items_json, $total_amount, $payment_status, $payment_mode, $payment_utr, $paid_amount, $paid_at, $delivery_address);
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
                payment_status VARCHAR(50) DEFAULT 'unpaid',
                payment_mode VARCHAR(50) DEFAULT 'Cash on Delivery',
                payment_utr VARCHAR(100) DEFAULT NULL,
                paid_amount DECIMAL(10,2) DEFAULT 0.00,
                paid_at VARCHAR(50) DEFAULT NULL,
                delivery_address TEXT DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(customer_mobile),
                INDEX(seller_username)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

            $colCheckCoPayMode = $conn->query("SHOW COLUMNS FROM customer_orders LIKE 'payment_mode'");
            if (!$colCheckCoPayMode || $colCheckCoPayMode->num_rows == 0) {
                @$conn->query("ALTER TABLE customer_orders ADD COLUMN payment_mode VARCHAR(50) DEFAULT 'Cash on Delivery'");
            }
            $colCheckCoDelAddr = $conn->query("SHOW COLUMNS FROM customer_orders LIKE 'delivery_address'");
            if (!$colCheckCoDelAddr || $colCheckCoDelAddr->num_rows == 0) {
                @$conn->query("ALTER TABLE customer_orders ADD COLUMN delivery_address TEXT DEFAULT NULL");
            }

            @$conn->query("INSERT INTO customer_orders (order_number, seller_username, seller_name, customer_mobile, customer_name, items_json, total_amount, total_count, order_status, payment_status, payment_mode, payment_utr, paid_amount, paid_at, delivery_address) VALUES ('$orderNumber', '$escapedSeller', '" . $conn->real_escape_string($seller_name) . "', '$customer_mobile', '" . $conn->real_escape_string($customer_name) . "', '" . $conn->real_escape_string($items_json) . "', $total_amount, $total_count, 'PENDING', '" . $conn->real_escape_string($payment_status) . "', '" . $conn->real_escape_string($payment_mode) . "', '" . $conn->real_escape_string($payment_utr) . "', $paid_amount, " . ($paid_at ? "'$paid_at'" : "NULL") . ", '" . $conn->real_escape_string($delivery_address) . "')");

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
                    "payment_mode" => $payment_mode,
                    "payment_status" => $payment_status,
                    "payment_utr" => $payment_utr,
                    "paid_amount" => $paid_amount,
                    "delivery_address" => $delivery_address,
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
    $query = "SELECT m.*, c.name as customer_name, s.name as seller_name, s.location as seller_location FROM messages m LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) LEFT JOIN sellers s ON (m.seller_username = s.username OR LOWER(m.seller_username) = LOWER(s.username)) WHERE (m.seller_username = '$escapedSeller' OR LOWER(m.seller_username) = LOWER('$escapedSeller') OR m.seller_username LIKE '%$escapedSeller%') AND (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%') ORDER BY m.id DESC";

    $res = $conn->query($query);
    $orders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['customer_name'] = !empty($row['customer_name']) ? $row['customer_name'] : "Customer ({$row['customer_mobile']})";
            if (empty($row['delivery_address'])) {
                if (!empty($row['message']) && preg_match('/(?:Address|delivery_address|📍\s*Address):\s*([^\r\n]+)/iu', $row['message'], $mAddr)) {
                    $row['delivery_address'] = trim($mAddr[1]);
                } elseif (!empty($row['customer_profile_address'])) {
                    $row['delivery_address'] = trim($row['customer_profile_address']);
                }
            }
            $orders[] = $row;
        }
    }
    echo json_encode(["success" => true, "orders" => $orders]);
    exit();
} elseif ($action == 'get-undelivered-orders') {
    $location = isset($_GET['location']) ? strtolower(trim($_GET['location'])) : '';
    $query = "SELECT m.*, c.name as customer_name, s.name as seller_name, s.mobile as seller_mobile, s.location as seller_location 
              FROM messages m 
              LEFT JOIN customers c ON (m.customer_mobile = c.mobile OR c.mobile LIKE CONCAT('%', RIGHT(m.customer_mobile, 10))) 
              LEFT JOIN sellers s ON (m.seller_username = s.username OR LOWER(m.seller_username) = LOWER(s.username)) 
              WHERE (m.items_json IS NOT NULL OR m.order_id IS NOT NULL OR m.message LIKE '%ORDER%')
                AND (LOWER(m.order_status) IN ('ready', 'approved') OR LOWER(m.delivery_status) IN ('out for delivery', 'picked up', 'pickup'))
                AND (m.delivery_status IS NULL OR LOWER(m.delivery_status) NOT IN ('delivered', 'cancelled'))
                AND (m.order_status IS NULL OR LOWER(m.order_status) NOT IN ('cancelled', 'deleted', 'delivered'))
              ORDER BY m.id DESC";

    $res = $conn->query($query);
    $orders = array();
    if ($res && $res !== true) {
        while ($row = $res->fetch_assoc()) {
            $row['id'] = (int)$row['id'];
            $row['customer_name'] = !empty($row['customer_name']) ? $row['customer_name'] : "Customer ({$row['customer_mobile']})";
            $row['seller_name'] = !empty($row['seller_name']) ? $row['seller_name'] : $row['seller_username'];
            if (!empty($location)) {
                $sLoc = strtolower(trim($row['seller_location'] ?? ''));
                if (!empty($sLoc) && $sLoc !== $location) {
                    continue;
                }
            }
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
} elseif ($action == 'check-first-order') {
    $customer_mobile = isset($_GET['customer_mobile']) ? trim($_GET['customer_mobile']) : (isset($input['customer_mobile']) ? trim($input['customer_mobile']) : '');
    $digits = preg_replace('/[^0-9]/', '', $customer_mobile);
    $last10 = (strlen($digits) >= 10) ? substr($digits, -10) : $digits;

    if (empty($last10)) {
        echo json_encode(["success" => true, "is_first_order" => false, "order_count" => 0]);
        exit();
    }

    $escapedLike = "%" . $conn->real_escape_string($last10) . "%";

    // 1. Check for DELIVERED orders (if delivered > 0, customer is no longer eligible for first order gift)
    $deliveredCount = 0;
    $msgDelivQuery = "SELECT COUNT(*) as cnt FROM messages WHERE (customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$escapedLike' OR customer_mobile LIKE '%$last10%') AND (LOWER(order_status) = 'delivered' OR LOWER(delivery_status) = 'delivered')";
    $resDeliv = $conn->query($msgDelivQuery);
    if ($resDeliv && $rowDeliv = $resDeliv->fetch_assoc()) {
        $deliveredCount = (int)$rowDeliv['cnt'];
    }

    $checkTable = $conn->query("SHOW TABLES LIKE 'customer_orders'");
    if ($checkTable && $checkTable->num_rows > 0) {
        $coDelivQuery = "SELECT COUNT(*) as cnt FROM customer_orders WHERE (customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$escapedLike') AND (LOWER(order_status) = 'delivered' OR LOWER(delivery_status) = 'delivered')";
        $resCoDeliv = $conn->query($coDelivQuery);
        if ($resCoDeliv && $rowCoDeliv = $resCoDeliv->fetch_assoc()) {
            $deliveredCount = max($deliveredCount, (int)$rowCoDeliv['cnt']);
        }
    }

    if ($deliveredCount > 0) {
        echo json_encode([
            "success" => true,
            "is_first_order" => false,
            "has_delivered_order" => true,
            "delivered_count" => $deliveredCount,
            "active_count" => 0
        ]);
        exit();
    }

    // 2. Check for active (pending / in-progress non-cancelled) orders
    $activeCount = 0;
    $msgActiveQuery = "SELECT COUNT(*) as cnt FROM messages WHERE (customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$escapedLike' OR customer_mobile LIKE '%$last10%') AND (items_json IS NOT NULL OR order_id IS NOT NULL OR message LIKE '%ORDER%') AND (order_status IS NULL OR LOWER(order_status) NOT IN ('cancelled', 'deleted', 'delivered')) AND (delivery_status IS NULL OR LOWER(delivery_status) NOT IN ('cancelled', 'deleted', 'delivered'))";
    $resActive = $conn->query($msgActiveQuery);
    if ($resActive && $rowActive = $resActive->fetch_assoc()) {
        $activeCount = (int)$rowActive['cnt'];
    }

    if ($checkTable && $checkTable->num_rows > 0) {
        $coActiveQuery = "SELECT COUNT(*) as cnt FROM customer_orders WHERE (customer_mobile = '$customer_mobile' OR customer_mobile LIKE '$escapedLike') AND (order_status IS NULL OR LOWER(order_status) NOT IN ('cancelled', 'deleted', 'delivered')) AND (delivery_status IS NULL OR LOWER(delivery_status) NOT IN ('cancelled', 'deleted', 'delivered'))";
        $resCoActive = $conn->query($coActiveQuery);
        if ($resCoActive && $rowCoActive = $resCoActive->fetch_assoc()) {
            $activeCount = max($activeCount, (int)$rowCoActive['cnt']);
        }
    }

    $isFirst = ($deliveredCount == 0 && $activeCount == 0);

    echo json_encode([
        "success" => true,
        "is_first_order" => $isFirst,
        "delivered_count" => $deliveredCount,
        "active_count" => $activeCount
    ]);
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
    $purchase_rate = isset($input['purchase_rate']) ? (float)$input['purchase_rate'] : (isset($input['p_rate']) ? (float)$input['p_rate'] : 0.0);
    $button_text = isset($input['button_text']) && !empty(trim($input['button_text'])) ? trim($input['button_text']) : 'Buy Now';
    $variants_raw = isset($input['variants']) ? $input['variants'] : '[]';
    $variants = is_array($variants_raw) ? json_encode($variants_raw) : (string)$variants_raw;

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

    $colCheckPurRate = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'purchase_rate'");
    if (!$colCheckPurRate || $colCheckPurRate->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN purchase_rate DECIMAL(10,2) DEFAULT 0.00");
    }

    $colCheckVariants = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'variants'");
    if (!$colCheckVariants || $colCheckVariants->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN variants LONGTEXT DEFAULT NULL");
    }

    $stmt = $conn->prepare("INSERT INTO seller_products (seller_username, name, description, unit, category, section, qty, rate, purchase_rate, image_url, button_text, variants) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("sssssiddssss", $seller_username, $name, $description, $unit, $category, $section, $qty, $rate, $purchase_rate, $image_url, $button_text, $variants);
        if ($stmt->execute()) {
            $newId = $stmt->insert_id;
            $decodedVariants = json_decode($variants, true);
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
                    "purchase_rate" => $purchase_rate,
                    "image_url" => $image_url,
                    "button_text" => $button_text,
                    "variants" => is_array($decodedVariants) ? $decodedVariants : array()
                ]
            ]);
            exit();
        }
    }
    echo json_encode(["success" => false, "message" => "Failed to add product"]);
    exit();
} elseif ($action == 'bulk-add-seller-products') {
    $colCheckProdImg = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'image_url'");
    if (!$colCheckProdImg || $colCheckProdImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN image_url LONGTEXT DEFAULT NULL");
    }
    $colCheckProdSec = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'section'");
    if (!$colCheckProdSec || $colCheckProdSec->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN section VARCHAR(255) DEFAULT NULL");
    }
    $colCheckLongDesc = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'long_description'");
    if (!$colCheckLongDesc || $colCheckLongDesc->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN long_description LONGTEXT DEFAULT NULL");
    }
    $colCheckPurRate = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'purchase_rate'");
    if (!$colCheckPurRate || $colCheckPurRate->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN purchase_rate DECIMAL(10,2) DEFAULT 0.00");
    }

    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : '';
    $products = isset($input['products']) && is_array($input['products']) ? $input['products'] : array();

    if (empty($seller_username) || empty($products)) {
        echo json_encode(["success" => false, "message" => "Seller username and non-empty products list required"]);
        exit();
    }

    $insertedProducts = array();
    $stmt = $conn->prepare("INSERT INTO seller_products (seller_username, name, description, long_description, unit, category, section, qty, rate, purchase_rate, image_url, button_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

    foreach ($products as $p) {
        $name = isset($p['name']) ? trim($p['name']) : '';
        if (empty($name)) continue;

        $description = isset($p['description']) ? trim($p['description']) : '';
        $long_description = isset($p['long_description']) ? trim($p['long_description']) : '';
        $unit = isset($p['unit']) && !empty(trim($p['unit'])) ? trim($p['unit']) : 'Pcs';
        $category = isset($p['category']) ? trim($p['category']) : '';
        $section = isset($p['section']) ? trim($p['section']) : '';
        $qty = isset($p['qty']) ? (int)$p['qty'] : 1;
        if ($qty <= 0) $qty = 1;
        $rate = isset($p['rate']) ? (float)$p['rate'] : (isset($p['sale_rate']) ? (float)$p['sale_rate'] : 0.0);
        $purchase_rate = isset($p['purchase_rate']) ? (float)$p['purchase_rate'] : (isset($p['purchase_price']) ? (float)$p['purchase_price'] : 0.0);
        $image_url = isset($p['image_url']) ? trim($p['image_url']) : '';
        $button_text = isset($p['button_text']) && !empty(trim($p['button_text'])) ? trim($p['button_text']) : 'Buy Now';

        if ($stmt) {
            $stmt->bind_param("sssssssiddss", $seller_username, $name, $description, $long_description, $unit, $category, $section, $qty, $rate, $purchase_rate, $image_url, $button_text);
            if ($stmt->execute()) {
                $newId = $stmt->insert_id;
                $insertedProducts[] = [
                    "id" => $newId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "description" => $description,
                    "long_description" => $long_description,
                    "unit" => $unit,
                    "category" => $category,
                    "section" => $section,
                    "qty" => $qty,
                    "rate" => $rate,
                    "purchase_rate" => $purchase_rate,
                    "image_url" => $image_url,
                    "button_text" => $button_text
                ];

                // Auto-create category if missing
                if (!empty($category)) {
                    $escCat = $conn->real_escape_string($category);
                    $escSeller = $conn->real_escape_string($seller_username);
                    $catCheck = $conn->query("SELECT id FROM seller_categories WHERE seller_username = '$escSeller' AND LOWER(name) = LOWER('$escCat')");
                    if (!$catCheck || $catCheck->num_rows == 0) {
                        @$conn->query("INSERT INTO seller_categories (seller_username, name, image_url, ring_color) VALUES ('$escSeller', '$escCat', '📁', '#8B5CF6')");
                    }
                }

                // Auto-create section if missing
                if (!empty($section)) {
                    $escSec = $conn->real_escape_string($section);
                    $escSeller = $conn->real_escape_string($seller_username);
                    $secCheck = $conn->query("SELECT id FROM seller_sections WHERE seller_username = '$escSeller' AND LOWER(name) = LOWER('$escSec')");
                    if (!$secCheck || $secCheck->num_rows == 0) {
                        @$conn->query("INSERT INTO seller_sections (seller_username, name, icon, bg_color, text_color, columns, max_items) VALUES ('$escSeller', '$escSec', '🏷️', '#FFFFFF', '#EF4444', 2, 0)");
                    }
                }

                // Auto-create unit if missing
                if (!empty($unit)) {
                    $escUnit = $conn->real_escape_string($unit);
                    $escSeller = $conn->real_escape_string($seller_username);
                    $unitCheck = $conn->query("SELECT id FROM seller_units WHERE seller_username = '$escSeller' AND LOWER(name) = LOWER('$escUnit')");
                    if (!$unitCheck || $unitCheck->num_rows == 0) {
                        @$conn->query("INSERT INTO seller_units (seller_username, name) VALUES ('$escSeller', '$escUnit')");
                    }
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "message" => count($insertedProducts) . " products imported successfully",
        "count" => count($insertedProducts),
        "products" => $insertedProducts
    ]);
    exit();
} elseif ($action == 'get-seller-products') {
    $colCheckBtnText = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'button_text'");
    if (!$colCheckBtnText || $colCheckBtnText->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN button_text VARCHAR(100) DEFAULT 'Buy Now'");
    }
    $colCheckVariants = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'variants'");
    if (!$colCheckVariants || $colCheckVariants->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN variants LONGTEXT DEFAULT NULL");
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
            if (isset($row['variants']) && is_string($row['variants']) && !empty($row['variants'])) {
                $decodedVar = json_decode($row['variants'], true);
                $row['variants'] = is_array($decodedVar) ? $decodedVar : array();
            } elseif (!isset($row['variants']) || !is_array($row['variants'])) {
                $row['variants'] = array();
            }
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
                if (isset($row['variants']) && is_string($row['variants']) && !empty($row['variants'])) {
                    $decodedVar = json_decode($row['variants'], true);
                    $row['variants'] = is_array($decodedVar) ? $decodedVar : array();
                } elseif (!isset($row['variants']) || !is_array($row['variants'])) {
                    $row['variants'] = array();
                }
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
    $colCheckVariants = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'variants'");
    if (!$colCheckVariants || $colCheckVariants->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN variants LONGTEXT DEFAULT NULL");
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
    $purchase_rate = isset($input['purchase_rate']) ? (float)$input['purchase_rate'] : (isset($input['p_rate']) ? (float)$input['p_rate'] : 0.0);
    $image_url = isset($input['image_url']) ? trim($input['image_url']) : (isset($input['image']) ? trim($input['image']) : '');
    $button_text = isset($input['button_text']) && !empty(trim($input['button_text'])) ? trim($input['button_text']) : 'Buy Now';
    $variants_raw = isset($input['variants']) ? $input['variants'] : '[]';
    $variants = is_array($variants_raw) ? json_encode($variants_raw) : (string)$variants_raw;

    if ($id <= 0 || empty($name)) {
        echo json_encode(["success" => false, "message" => "Product ID and name required"]);
        exit();
    }

    $colCheckPurRate = $conn->query("SHOW COLUMNS FROM seller_products LIKE 'purchase_rate'");
    if (!$colCheckPurRate || $colCheckPurRate->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_products ADD COLUMN purchase_rate DECIMAL(10,2) DEFAULT 0.00");
    }

    $stmt = $conn->prepare("UPDATE seller_products SET name = ?, description = ?, unit = ?, category = ?, section = ?, qty = ?, rate = ?, purchase_rate = ?, image_url = ?, button_text = ?, variants = ? WHERE id = ?");
    if ($stmt) {
        $stmt->bind_param("sssssiddsssi", $name, $description, $unit, $category, $section, $qty, $rate, $purchase_rate, $image_url, $button_text, $variants, $id);
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
    $colCheckMaxItems = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'max_items'");
    if (!$colCheckMaxItems || $colCheckMaxItems->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN max_items INT DEFAULT 0");
    }
    $colCheckSecFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'full_width'");
    if (!$colCheckSecFullWidth || $colCheckSecFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN full_width INT DEFAULT 0");
    }
    $colCheckSecPosterFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'poster_full_width'");
    if (!$colCheckSecPosterFullWidth || $colCheckSecPosterFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN poster_full_width INT DEFAULT 0");
    }
    $colCheckHideTitle = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_title'");
    if (!$colCheckHideTitle || $colCheckHideTitle->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_title INT DEFAULT 0");
    }
    $colCheckHideItemCount = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_item_count'");
    if (!$colCheckHideItemCount || $colCheckHideItemCount->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_item_count INT DEFAULT 0");
    }
    $colCheckImgBg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'image_bg_color'");
    if (!$colCheckImgBg || $colCheckImgBg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN image_bg_color VARCHAR(50) DEFAULT '#F8FAFC'");
    }
    $colCheckHeadingImg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'heading_image'");
    if (!$colCheckHeadingImg || $colCheckHeadingImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN heading_image LONGTEXT DEFAULT NULL");
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
            $row['max_items'] = isset($row['max_items']) ? (int)$row['max_items'] : 0;
            $row['full_width'] = isset($row['full_width']) ? (int)$row['full_width'] : 0;
            $row['poster_full_width'] = isset($row['poster_full_width']) ? (int)$row['poster_full_width'] : 0;
            $row['hide_title'] = isset($row['hide_title']) ? (int)$row['hide_title'] : 0;
            $row['hide_item_count'] = isset($row['hide_item_count']) ? (int)$row['hide_item_count'] : 0;
            $row['image_bg_color'] = isset($row['image_bg_color']) && !empty($row['image_bg_color']) ? $row['image_bg_color'] : '#F8FAFC';
            $row['heading_image'] = isset($row['heading_image']) ? $row['heading_image'] : '';
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
    $colCheckMaxItems = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'max_items'");
    if (!$colCheckMaxItems || $colCheckMaxItems->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN max_items INT DEFAULT 0");
    }
    $colCheckSecFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'full_width'");
    if (!$colCheckSecFullWidth || $colCheckSecFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN full_width INT DEFAULT 0");
    }
    $colCheckSecPosterFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'poster_full_width'");
    if (!$colCheckSecPosterFullWidth || $colCheckSecPosterFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN poster_full_width INT DEFAULT 0");
    }
    $colCheckHideTitle = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_title'");
    if (!$colCheckHideTitle || $colCheckHideTitle->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_title INT DEFAULT 0");
    }
    $colCheckHideItemCount = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_item_count'");
    if (!$colCheckHideItemCount || $colCheckHideItemCount->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_item_count INT DEFAULT 0");
    }
    $colCheckImgBg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'image_bg_color'");
    if (!$colCheckImgBg || $colCheckImgBg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN image_bg_color VARCHAR(50) DEFAULT '#F8FAFC'");
    }
    $colCheckHeadingImg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'heading_image'");
    if (!$colCheckHeadingImg || $colCheckHeadingImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN heading_image LONGTEXT DEFAULT NULL");
    }

    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $name = isset($input['name']) ? trim($input['name']) : (isset($_GET['name']) ? trim($_GET['name']) : (isset($_POST['name']) ? trim($_POST['name']) : ''));
    $icon = isset($input['icon']) ? trim($input['icon']) : '🏷️';
    $bg_color = isset($input['bg_color']) ? trim($input['bg_color']) : '#FFFFFF';
    $text_color = isset($input['text_color']) ? trim($input['text_color']) : '#0F172A';
    $columns = isset($input['columns']) ? (int)$input['columns'] : 2;
    if ($columns <= 0 || $columns > 3) $columns = 2;
    $max_items = isset($input['max_items']) ? (int)$input['max_items'] : 0;
    if ($max_items < 0) $max_items = 0;
    $full_width = isset($input['full_width']) ? (int)$input['full_width'] : (isset($_POST['full_width']) ? (int)$_POST['full_width'] : 0);
    if ($full_width != 1) $full_width = 0;
    $poster_full_width = isset($input['poster_full_width']) ? (int)$input['poster_full_width'] : (isset($_POST['poster_full_width']) ? (int)$_POST['poster_full_width'] : 0);
    if ($poster_full_width != 1) $poster_full_width = 0;
    $hide_title = isset($input['hide_title']) ? (int)$input['hide_title'] : (isset($_POST['hide_title']) ? (int)$_POST['hide_title'] : 0);
    if ($hide_title != 1) $hide_title = 0;
    $hide_item_count = isset($input['hide_item_count']) ? (int)$input['hide_item_count'] : (isset($_POST['hide_item_count']) ? (int)$_POST['hide_item_count'] : 0);
    if ($hide_item_count != 1) $hide_item_count = 0;
    $image_bg_color = isset($input['image_bg_color']) ? trim($input['image_bg_color']) : (isset($_POST['image_bg_color']) ? trim($_POST['image_bg_color']) : '#F8FAFC');
    if (empty($image_bg_color)) $image_bg_color = '#F8FAFC';
    $heading_image = isset($input['heading_image']) ? trim($input['heading_image']) : (isset($_POST['heading_image']) ? trim($_POST['heading_image']) : '');

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and section name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);

    // Sync matching sliders full_width
    @$conn->query("UPDATE seller_sliders SET full_width = $poster_full_width WHERE (seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller')) AND LOWER(section) = LOWER('$escapedName')");

    $chk = $conn->query("SELECT id FROM seller_sections WHERE seller_username = '$escapedSeller' AND name = '$escapedName' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        $existingId = (int)$row['id'];
        $stmtUp = $conn->prepare("UPDATE seller_sections SET icon = ?, bg_color = ?, text_color = ?, columns = ?, max_items = ?, full_width = ?, poster_full_width = ?, hide_title = ?, hide_item_count = ?, image_bg_color = ?, heading_image = ? WHERE id = ?");
        if ($stmtUp) {
            $stmtUp->bind_param("sssiiiiisssi", $icon, $bg_color, $text_color, $columns, $max_items, $full_width, $poster_full_width, $hide_title, $hide_item_count, $image_bg_color, $heading_image, $existingId);
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
                "columns" => $columns,
                "max_items" => $max_items,
                "full_width" => $full_width,
                "poster_full_width" => $poster_full_width,
                "hide_title" => $hide_title,
                "hide_item_count" => $hide_item_count,
                "image_bg_color" => $image_bg_color,
                "heading_image" => $heading_image
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_sections (seller_username, name, icon, bg_color, text_color, columns, max_items, full_width, poster_full_width, hide_title, hide_item_count, image_bg_color, heading_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("sssssiiiiisss", $seller_username, $name, $icon, $bg_color, $text_color, $columns, $max_items, $full_width, $poster_full_width, $hide_title, $hide_item_count, $image_bg_color, $heading_image);
        if ($stmt->execute()) {
            $insertedId = $conn->insert_id;
            echo json_encode([
                "success" => true,
                "message" => "Section added",
                "section" => [
                    "id" => $insertedId,
                    "seller_username" => $seller_username,
                    "name" => $name,
                    "icon" => $icon,
                    "bg_color" => $bg_color,
                    "text_color" => $text_color,
                    "columns" => $columns,
                    "max_items" => $max_items,
                    "full_width" => $full_width,
                    "poster_full_width" => $poster_full_width,
                    "hide_title" => $hide_title,
                    "hide_item_count" => $hide_item_count,
                    "image_bg_color" => $image_bg_color,
                    "heading_image" => $heading_image
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
    $colCheckMaxItems = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'max_items'");
    if (!$colCheckMaxItems || $colCheckMaxItems->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN max_items INT DEFAULT 0");
    }
    $colCheckSecFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'full_width'");
    if (!$colCheckSecFullWidth || $colCheckSecFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN full_width INT DEFAULT 0");
    }
    $colCheckSecPosterFullWidth = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'poster_full_width'");
    if (!$colCheckSecPosterFullWidth || $colCheckSecPosterFullWidth->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN poster_full_width INT DEFAULT 0");
    }
    $colCheckHideTitle = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_title'");
    if (!$colCheckHideTitle || $colCheckHideTitle->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_title INT DEFAULT 0");
    }
    $colCheckHideItemCount = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'hide_item_count'");
    if (!$colCheckHideItemCount || $colCheckHideItemCount->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN hide_item_count INT DEFAULT 0");
    }
    $colCheckImgBg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'image_bg_color'");
    if (!$colCheckImgBg || $colCheckImgBg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN image_bg_color VARCHAR(50) DEFAULT '#F8FAFC'");
    }
    $colCheckHeadingImg = $conn->query("SHOW COLUMNS FROM seller_sections LIKE 'heading_image'");
    if (!$colCheckHeadingImg || $colCheckHeadingImg->num_rows == 0) {
        @$conn->query("ALTER TABLE seller_sections ADD COLUMN heading_image LONGTEXT DEFAULT NULL");
    }

    $id = isset($input['id']) ? (int)$input['id'] : (isset($_POST['id']) ? (int)$_POST['id'] : 0);
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : ''));
    $name = isset($input['name']) ? trim($input['name']) : (isset($_POST['name']) ? trim($_POST['name']) : '');
    $icon = isset($input['icon']) ? trim($input['icon']) : '🏷️';
    $bg_color = isset($input['bg_color']) ? trim($input['bg_color']) : '#FFFFFF';
    $text_color = isset($input['text_color']) ? trim($input['text_color']) : '#0F172A';
    $columns = isset($input['columns']) ? (int)$input['columns'] : 2;
    if ($columns <= 0 || $columns > 3) $columns = 2;
    $max_items = isset($input['max_items']) ? (int)$input['max_items'] : 0;
    if ($max_items < 0) $max_items = 0;
    $full_width = isset($input['full_width']) ? (int)$input['full_width'] : (isset($_POST['full_width']) ? (int)$_POST['full_width'] : 0);
    if ($full_width != 1) $full_width = 0;
    $poster_full_width = isset($input['poster_full_width']) ? (int)$input['poster_full_width'] : (isset($_POST['poster_full_width']) ? (int)$_POST['poster_full_width'] : 0);
    if ($poster_full_width != 1) $poster_full_width = 0;
    $hide_title = isset($input['hide_title']) ? (int)$input['hide_title'] : (isset($_POST['hide_title']) ? (int)$_POST['hide_title'] : 0);
    if ($hide_title != 1) $hide_title = 0;
    $hide_item_count = isset($input['hide_item_count']) ? (int)$input['hide_item_count'] : (isset($_POST['hide_item_count']) ? (int)$_POST['hide_item_count'] : 0);
    if ($hide_item_count != 1) $hide_item_count = 0;
    $image_bg_color = isset($input['image_bg_color']) ? trim($input['image_bg_color']) : (isset($_POST['image_bg_color']) ? trim($_POST['image_bg_color']) : '#F8FAFC');
    if (empty($image_bg_color)) $image_bg_color = '#F8FAFC';
    $heading_image = isset($input['heading_image']) ? trim($input['heading_image']) : (isset($_POST['heading_image']) ? trim($_POST['heading_image']) : '');

    if (empty($name)) {
        echo json_encode(["success" => false, "message" => "Section name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);

    // Sync matching sliders full_width
    @$conn->query("UPDATE seller_sliders SET full_width = $poster_full_width WHERE (seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller')) AND LOWER(section) = LOWER('$escapedName')");

    $updated = false;
    if ($id > 0) {
        $stmt = $conn->prepare("UPDATE seller_sections SET name = ?, icon = ?, bg_color = ?, text_color = ?, columns = ?, max_items = ?, full_width = ?, poster_full_width = ?, hide_title = ?, hide_item_count = ?, image_bg_color = ?, heading_image = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("ssssiiiiisssi", $name, $icon, $bg_color, $text_color, $columns, $max_items, $full_width, $poster_full_width, $hide_title, $hide_item_count, $image_bg_color, $heading_image, $id);
            if ($stmt->execute()) {
                $updated = true;
            }
        }
    }

    if (!$updated && !empty($seller_username)) {
        $stmt = $conn->prepare("UPDATE seller_sections SET icon = ?, bg_color = ?, text_color = ?, columns = ?, max_items = ?, full_width = ?, poster_full_width = ?, hide_title = ?, hide_item_count = ?, image_bg_color = ?, heading_image = ? WHERE seller_username = ? AND name = ?");
        if ($stmt) {
            $stmt->bind_param("sssiiiiisssss", $icon, $bg_color, $text_color, $columns, $max_items, $full_width, $poster_full_width, $hide_title, $hide_item_count, $image_bg_color, $heading_image, $seller_username, $name);
            if ($stmt->execute()) {
                $updated = true;
            }
        }
    }

    if (!$updated && !empty($seller_username)) {
        $stmtIns = $conn->prepare("INSERT INTO seller_sections (seller_username, name, icon, bg_color, text_color, columns, max_items, full_width, poster_full_width, hide_title, hide_item_count, image_bg_color, heading_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
        if ($stmtIns) {
            $stmtIns->bind_param("sssssiiiiisss", $seller_username, $name, $icon, $bg_color, $text_color, $columns, $max_items, $full_width, $poster_full_width, $hide_title, $hide_item_count, $image_bg_color, $heading_image);
            $stmtIns->execute();
        }
    }

    echo json_encode([
        "success" => true,
        "message" => "Section updated",
        "columns" => $columns,
        "max_items" => $max_items,
        "full_width" => $full_width,
        "poster_full_width" => $poster_full_width,
        "hide_title" => $hide_title,
        "hide_item_count" => $hide_item_count,
        "image_bg_color" => $image_bg_color,
        "heading_image" => $heading_image
    ]);
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
    $icon_url = isset($input['icon_url']) ? trim($input['icon_url']) : '';
    $poster_url = isset($input['poster_url']) ? trim($input['poster_url']) : '';
    $item_bg_color = isset($input['item_bg_color']) ? trim($input['item_bg_color']) : (isset($_GET['item_bg_color']) ? trim($_GET['item_bg_color']) : '#F8FAFC');
    if (empty($item_bg_color)) $item_bg_color = '#F8FAFC';
    $sections = isset($input['sections']) ? trim($input['sections']) : (isset($_GET['sections']) ? trim($_GET['sections']) : '');
    $hide_name = isset($input['hide_name']) ? (int)$input['hide_name'] : (isset($_GET['hide_name']) ? (int)$_GET['hide_name'] : 0);
    $full_size_image = isset($input['full_size_image']) ? (int)$input['full_size_image'] : (isset($_GET['full_size_image']) ? (int)$_GET['full_size_image'] : 0);

    if (empty($seller_username) || empty($name)) {
        echo json_encode(["success" => false, "message" => "Seller username and category name required"]);
        exit();
    }

    $escapedSeller = $conn->real_escape_string($seller_username);
    $escapedName = $conn->real_escape_string($name);
    $chk = $conn->query("SELECT id, image_url, color, icon_url, poster_url, item_bg_color, sections, hide_name, full_size_image FROM seller_categories WHERE seller_username = '$escapedSeller' AND name = '$escapedName' LIMIT 1");
    if ($chk && $row = $chk->fetch_assoc()) {
        $cId = (int)$row['id'];
        $finalImg = !empty($image_url) ? $image_url : $row['image_url'];
        $finalIcon = !empty($icon_url) ? $icon_url : $row['icon_url'];
        $finalPoster = !empty($poster_url) ? $poster_url : (isset($row['poster_url']) ? $row['poster_url'] : '');
        $finalItemBg = !empty($item_bg_color) ? $item_bg_color : (isset($row['item_bg_color']) ? $row['item_bg_color'] : '#F8FAFC');
        $finalSections = !empty($sections) ? $sections : (isset($row['sections']) ? $row['sections'] : '');
        $finalHideName = $hide_name !== null ? $hide_name : (isset($row['hide_name']) ? (int)$row['hide_name'] : 0);
        $finalFullSize = $full_size_image !== null ? $full_size_image : (isset($row['full_size_image']) ? (int)$row['full_size_image'] : 0);

        $upStmt = $conn->prepare("UPDATE seller_categories SET color = ?, image_url = ?, icon_url = ?, poster_url = ?, item_bg_color = ?, sections = ?, hide_name = ?, full_size_image = ? WHERE id = ?");
        if ($upStmt) {
            $upStmt->bind_param("ssssssiii", $color, $finalImg, $finalIcon, $finalPoster, $finalItemBg, $finalSections, $finalHideName, $finalFullSize, $cId);
            $upStmt->execute();
        }

        echo json_encode([
            "success" => true,
            "message" => "Category updated in database",
            "category" => [
                "id" => $cId,
                "seller_username" => $seller_username,
                "name" => $name,
                "image_url" => $finalImg,
                "color" => $color,
                "icon_url" => $finalIcon,
                "poster_url" => $finalPoster,
                "item_bg_color" => $finalItemBg,
                "sections" => $finalSections,
                "hide_name" => $finalHideName,
                "full_size_image" => $finalFullSize
            ]
        ]);
        exit();
    }

    $stmt = $conn->prepare("INSERT INTO seller_categories (seller_username, name, image_url, color, icon_url, poster_url, item_bg_color, sections, hide_name, full_size_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    if ($stmt) {
        $stmt->bind_param("ssssssssii", $seller_username, $name, $image_url, $color, $icon_url, $poster_url, $item_bg_color, $sections, $hide_name, $full_size_image);
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
                    "color" => $color,
                    "icon_url" => $icon_url,
                    "poster_url" => $poster_url,
                    "item_bg_color" => $item_bg_color,
                    "sections" => $sections,
                    "hide_name" => $hide_name,
                    "full_size_image" => $full_size_image
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
    $icon_url = isset($input['icon_url']) ? trim($input['icon_url']) : '';
    $poster_url = isset($input['poster_url']) ? trim($input['poster_url']) : (isset($_GET['poster_url']) ? trim($_GET['poster_url']) : null);
    $item_bg_color = isset($input['item_bg_color']) ? trim($input['item_bg_color']) : (isset($_GET['item_bg_color']) ? trim($_GET['item_bg_color']) : null);
    $sections = isset($input['sections']) ? trim($input['sections']) : (isset($_GET['sections']) ? trim($_GET['sections']) : null);
    $hide_name = isset($input['hide_name']) ? (int)$input['hide_name'] : (isset($_GET['hide_name']) ? (int)$_GET['hide_name'] : null);
    $full_size_image = isset($input['full_size_image']) ? (int)$input['full_size_image'] : (isset($_GET['full_size_image']) ? (int)$_GET['full_size_image'] : null);

    if (empty($name)) {
        echo json_encode(["success" => false, "message" => "Category name required"]);
        exit();
    }

    $updated = false;

    // 1. Update by ID if ID > 0
    if ($id > 0) {
        $curRes = $conn->query("SELECT image_url, icon_url, poster_url, item_bg_color, sections, hide_name, full_size_image FROM seller_categories WHERE id = $id LIMIT 1");
        $curRow = $curRes ? $curRes->fetch_assoc() : null;
        $finalImg = !empty($image_url) ? $image_url : ($curRow ? $curRow['image_url'] : '');
        $finalIcon = !empty($icon_url) ? $icon_url : ($curRow ? $curRow['icon_url'] : '');
        $finalPoster = $poster_url !== null ? $poster_url : ($curRow ? (isset($curRow['poster_url']) ? $curRow['poster_url'] : '') : '');
        $finalItemBg = $item_bg_color !== null ? $item_bg_color : ($curRow ? (isset($curRow['item_bg_color']) ? $curRow['item_bg_color'] : '#F8FAFC') : '#F8FAFC');
        $finalSections = $sections !== null ? $sections : ($curRow ? (isset($curRow['sections']) ? $curRow['sections'] : '') : '');
        $finalHideName = $hide_name !== null ? $hide_name : ($curRow && isset($curRow['hide_name']) ? (int)$curRow['hide_name'] : 0);
        $finalFullSize = $full_size_image !== null ? $full_size_image : ($curRow && isset($curRow['full_size_image']) ? (int)$curRow['full_size_image'] : 0);

        $stmt = $conn->prepare("UPDATE seller_categories SET name = ?, image_url = ?, color = ?, icon_url = ?, poster_url = ?, item_bg_color = ?, sections = ?, hide_name = ?, full_size_image = ? WHERE id = ?");
        if ($stmt) {
            $stmt->bind_param("sssssssiii", $name, $finalImg, $color, $finalIcon, $finalPoster, $finalItemBg, $finalSections, $finalHideName, $finalFullSize, $id);
            if ($stmt->execute() && $stmt->affected_rows > 0) $updated = true;
        }
    }

    // 2. Fallback update by seller_username & name
    if (!$updated && !empty($seller_username)) {
        $curRes = $conn->query("SELECT id, image_url, icon_url, poster_url, item_bg_color, sections, hide_name, full_size_image FROM seller_categories WHERE seller_username = '" . $conn->real_escape_string($seller_username) . "' AND name = '" . $conn->real_escape_string($name) . "' LIMIT 1");
        $curRow = $curRes ? $curRes->fetch_assoc() : null;
        $finalImg = !empty($image_url) ? $image_url : ($curRow ? $curRow['image_url'] : '');
        $finalIcon = !empty($icon_url) ? $icon_url : ($curRow ? $curRow['icon_url'] : '');
        $finalPoster = $poster_url !== null ? $poster_url : ($curRow ? (isset($curRow['poster_url']) ? $curRow['poster_url'] : '') : '');
        $finalItemBg = $item_bg_color !== null ? $item_bg_color : ($curRow ? (isset($curRow['item_bg_color']) ? $curRow['item_bg_color'] : '#F8FAFC') : '#F8FAFC');
        $finalSections = $sections !== null ? $sections : ($curRow ? (isset($curRow['sections']) ? $curRow['sections'] : '') : '');
        $finalHideName = $hide_name !== null ? $hide_name : ($curRow && isset($curRow['hide_name']) ? (int)$curRow['hide_name'] : 0);
        $finalFullSize = $full_size_image !== null ? $full_size_image : ($curRow && isset($curRow['full_size_image']) ? (int)$curRow['full_size_image'] : 0);

        $stmt2 = $conn->prepare("UPDATE seller_categories SET color = ?, image_url = ?, icon_url = ?, poster_url = ?, item_bg_color = ?, sections = ?, hide_name = ?, full_size_image = ? WHERE seller_username = ? AND name = ?");
        if ($stmt2) {
            $stmt2->bind_param("ssssssiiss", $color, $finalImg, $finalIcon, $finalPoster, $finalItemBg, $finalSections, $finalHideName, $finalFullSize, $seller_username, $name);
            if ($stmt2->execute() && $stmt2->affected_rows > 0) $updated = true;
        }
    }

    echo json_encode(["success" => true, "message" => "Category updated in database", "color" => $color, "poster_url" => $poster_url, "item_bg_color" => $item_bg_color, "sections" => $sections, "hide_name" => $hide_name, "full_size_image" => $full_size_image, "updated" => $updated]);
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
} elseif ($action == 'save-seller-product-border') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $border_image = isset($input['border_image']) ? trim($input['border_image']) : '';
    if (empty($border_image) && isset($input['product_border'])) $border_image = trim($input['product_border']);
    if (empty($border_image) && isset($input['border'])) $border_image = trim($input['border']);

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $colCheckBorder = $conn->query("SHOW COLUMNS FROM sellers LIKE 'border_image'");
    if (!$colCheckBorder || $colCheckBorder->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN border_image LONGTEXT DEFAULT NULL");
    }

    // 1. Save into seller_borders table
    $stmt1 = $conn->prepare("INSERT INTO seller_borders (seller_username, border_image) VALUES (?, ?) ON DUPLICATE KEY UPDATE border_image = VALUES(border_image)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $border_image);
        $stmt1->execute();
    }

    // 2. Also save into sellers table for redundancy
    $stmt2 = $conn->prepare("UPDATE sellers SET border_image = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $border_image, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Product border saved in database successfully",
        "seller_username" => $seller_username,
        "border_image" => $border_image
    ]);
    exit();
} elseif ($action == 'get-seller-product-border') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $border_image = '';
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        // Check seller_borders table
        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_borders'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT border_image FROM seller_borders WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $border_image = trim($row1['border_image'] ?? '');
            }
        }

        // Fallback: check sellers table
        if (empty($border_image)) {
            $colCheckBorder = $conn->query("SHOW COLUMNS FROM sellers LIKE 'border_image'");
            if ($colCheckBorder && $colCheckBorder->num_rows > 0) {
                $res2 = $conn->query("SELECT border_image FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $border_image = trim($row2['border_image'] ?? '');
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "border_image" => $border_image,
        "product_border" => $border_image,
        "border" => $border_image
    ]);
    exit();
} elseif ($action == 'save-seller-header-animations') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $header_animations = '';
    if (isset($input['header_animations'])) {
        $header_animations = is_array($input['header_animations']) ? json_encode($input['header_animations']) : trim($input['header_animations']);
    } elseif (isset($input['animations'])) {
        $header_animations = is_array($input['animations']) ? json_encode($input['animations']) : trim($input['animations']);
    } elseif (isset($input['animations_list'])) {
        $header_animations = is_array($input['animations_list']) ? json_encode($input['animations_list']) : trim($input['animations_list']);
    }

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $colCheckAnim = $conn->query("SHOW COLUMNS FROM sellers LIKE 'header_animations'");
    if (!$colCheckAnim || $colCheckAnim->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN header_animations LONGTEXT DEFAULT NULL");
    }

    // 1. Save into seller_animations table
    $stmt1 = $conn->prepare("INSERT INTO seller_animations (seller_username, header_animations) VALUES (?, ?) ON DUPLICATE KEY UPDATE header_animations = VALUES(header_animations)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $header_animations);
        $stmt1->execute();
    }

    // 2. Also save into sellers table
    $stmt2 = $conn->prepare("UPDATE sellers SET header_animations = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $header_animations, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Header animations saved in database successfully",
        "seller_username" => $seller_username,
        "header_animations" => $header_animations
    ]);
    exit();
} elseif ($action == 'get-seller-header-animations') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $header_animations = '[]';
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        // 1. Check seller_animations table
        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_animations'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT header_animations FROM seller_animations WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                if (!empty($row1['header_animations'])) {
                    $header_animations = $row1['header_animations'];
                }
            }
        }

        // 2. Fallback: check sellers table
        if ($header_animations === '[]') {
            $colCheckAnim = $conn->query("SHOW COLUMNS FROM sellers LIKE 'header_animations'");
            if ($colCheckAnim && $colCheckAnim->num_rows > 0) {
                $res2 = $conn->query("SELECT header_animations FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    if (!empty($row2['header_animations'])) {
                        $header_animations = $row2['header_animations'];
                    }
                }
            }
        }
    }

    $decoded = json_decode($header_animations, true);

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "header_animations" => is_array($decoded) ? $decoded : $header_animations,
        "lottie_animations" => is_array($decoded) ? $decoded : $header_animations,
        "animations" => is_array($decoded) ? $decoded : $header_animations,
        "raw_json" => $header_animations
    ]);
    exit();
} elseif ($action == 'update-seller-profile') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($input['username']) ? trim($input['username']) : '');
    $border_image = isset($input['border_image']) ? trim($input['border_image']) : (isset($input['product_border']) ? trim($input['product_border']) : '');
    $header_animations = isset($input['header_animations']) ? (is_array($input['header_animations']) ? json_encode($input['header_animations']) : trim($input['header_animations'])) : '';

    if (!empty($seller_username) && !empty($border_image)) {
        $stmt = $conn->prepare("INSERT INTO seller_borders (seller_username, border_image) VALUES (?, ?) ON DUPLICATE KEY UPDATE border_image = VALUES(border_image)");
        if ($stmt) {
            $stmt->bind_param("ss", $seller_username, $border_image);
            $stmt->execute();
        }
    }

    if (!empty($seller_username) && !empty($header_animations)) {
        $stmt2 = $conn->prepare("INSERT INTO seller_animations (seller_username, header_animations) VALUES (?, ?) ON DUPLICATE KEY UPDATE header_animations = VALUES(header_animations)");
        if ($stmt2) {
            $stmt2->bind_param("ss", $seller_username, $header_animations);
            $stmt2->execute();
        }
    }

    $welcome_popup = isset($input['welcome_popup']) ? trim($input['welcome_popup']) : (isset($input['popup_image']) ? trim($input['popup_image']) : '');
    if (!empty($seller_username) && !empty($welcome_popup)) {
        $chkTable = $conn->query("SHOW TABLES LIKE 'seller_welcome_popups'");
        if (!$chkTable || $chkTable->num_rows == 0) {
            @$conn->query("CREATE TABLE IF NOT EXISTS seller_welcome_popups (
                seller_username VARCHAR(100) PRIMARY KEY,
                popup_image LONGTEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )");
        }
        $stmt3 = $conn->prepare("INSERT INTO seller_welcome_popups (seller_username, popup_image) VALUES (?, ?) ON DUPLICATE KEY UPDATE popup_image = VALUES(popup_image)");
        if ($stmt3) {
            $stmt3->bind_param("ss", $seller_username, $welcome_popup);
            $stmt3->execute();
        }
    }
    echo json_encode(["success" => true, "message" => "Seller profile updated"]);
    exit();
} elseif ($action == 'save-seller-welcome-popup') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $popup_image = isset($input['popup_image']) ? trim($input['popup_image']) : '';
    if (empty($popup_image) && isset($input['image'])) $popup_image = trim($input['image']);
    if (empty($popup_image) && isset($input['welcome_popup'])) $popup_image = trim($input['welcome_popup']);

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $colCheckPopup = $conn->query("SHOW COLUMNS FROM sellers LIKE 'welcome_popup'");
    if (!$colCheckPopup || $colCheckPopup->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN welcome_popup LONGTEXT DEFAULT NULL");
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_welcome_popups'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_welcome_popups (
            seller_username VARCHAR(100) PRIMARY KEY,
            popup_image LONGTEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )");
    }

    // 1. Save in seller_welcome_popups table
    $stmt1 = $conn->prepare("INSERT INTO seller_welcome_popups (seller_username, popup_image) VALUES (?, ?) ON DUPLICATE KEY UPDATE popup_image = VALUES(popup_image)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $popup_image);
        $stmt1->execute();
    }

    // 2. Also save into sellers table
    $stmt2 = $conn->prepare("UPDATE sellers SET welcome_popup = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $popup_image, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Welcome popup image saved successfully",
        "seller_username" => $seller_username,
        "popup_image" => $popup_image
    ]);
    exit();
} elseif ($action == 'get-seller-welcome-popup') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $popup_image = '';
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        // Check seller_welcome_popups table
        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_welcome_popups'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT popup_image FROM seller_welcome_popups WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $popup_image = trim($row1['popup_image'] ?? '');
            }
        }

        // Fallback: check sellers table
        if (empty($popup_image)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'welcome_popup'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT welcome_popup FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $popup_image = trim($row2['welcome_popup'] ?? '');
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "popup_image" => $popup_image,
        "welcome_popup" => $popup_image
    ]);
    exit();
} elseif ($action == 'save-seller-festival-animation') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $festival_animation = '';
    if (isset($input['festival_animation'])) {
        $festival_animation = is_array($input['festival_animation']) ? json_encode($input['festival_animation']) : trim($input['festival_animation']);
    } elseif (isset($input['animation'])) {
        $festival_animation = is_array($input['animation']) ? json_encode($input['animation']) : trim($input['animation']);
    }

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_festival_animations'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_festival_animations (
            seller_username VARCHAR(100) PRIMARY KEY,
            festival_animation LONGTEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )");
    }

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'festival_animation'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN festival_animation LONGTEXT DEFAULT NULL");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_festival_animations (seller_username, festival_animation) VALUES (?, ?) ON DUPLICATE KEY UPDATE festival_animation = VALUES(festival_animation)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $festival_animation);
        $stmt1->execute();
    }

    $stmt2 = $conn->prepare("UPDATE sellers SET festival_animation = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $festival_animation, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Festival animation saved successfully",
        "seller_username" => $seller_username,
        "festival_animation" => $festival_animation
    ]);
    exit();
} elseif ($action == 'get-seller-festival-animation') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $festival_animation = '';
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_festival_animations'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT festival_animation FROM seller_festival_animations WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $festival_animation = trim($row1['festival_animation'] ?? '');
            }
        }

        if (empty($festival_animation)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'festival_animation'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT festival_animation FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $festival_animation = trim($row2['festival_animation'] ?? '');
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "festival_animation" => $festival_animation
    ]);
    exit();
} elseif ($action == 'save-seller-related-item-bg') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $color = isset($input['color']) ? trim($input['color']) : (isset($_GET['color']) ? trim($_GET['color']) : '');
    if (empty($color) && isset($input['item_bg_color'])) $color = trim($input['item_bg_color']);
    if (empty($color) && isset($input['related_item_bg'])) $color = trim($input['related_item_bg']);
    if (empty($color)) $color = '#F8FAFC';

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_related_item_bgs'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_related_item_bgs (
            seller_username VARCHAR(100) PRIMARY KEY,
            item_bg_color VARCHAR(50) DEFAULT '#F8FAFC',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )");
    }

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'related_item_bg'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN related_item_bg VARCHAR(50) DEFAULT '#F8FAFC'");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_related_item_bgs (seller_username, item_bg_color) VALUES (?, ?) ON DUPLICATE KEY UPDATE item_bg_color = VALUES(item_bg_color)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $color);
        $stmt1->execute();
    }

    $stmt2 = $conn->prepare("UPDATE sellers SET related_item_bg = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $color, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Related item background color saved successfully",
        "seller_username" => $seller_username,
        "color" => $color
    ]);
    exit();
} elseif ($action == 'get-seller-related-item-bg') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $color = '#F8FAFC';
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_related_item_bgs'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT item_bg_color FROM seller_related_item_bgs WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $c = trim($row1['item_bg_color'] ?? '');
                if (!empty($c)) $color = $c;
            }
        }

        if ($color === '#F8FAFC') {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'related_item_bg'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT related_item_bg FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $c = trim($row2['related_item_bg'] ?? '');
                    if (!empty($c)) $color = $c;
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "color" => $color
    ]);
    exit();
} elseif ($action == 'save-seller-category-sections') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_GET['seller_username']) ? trim($_GET['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $category_sections = '';
    if (isset($input['category_sections'])) {
        $category_sections = is_array($input['category_sections']) ? json_encode($input['category_sections']) : trim($input['category_sections']);
    } elseif (isset($input['sections'])) {
        $category_sections = is_array($input['sections']) ? json_encode($input['sections']) : trim($input['sections']);
    }

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_category_sections'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_category_sections (
            seller_username VARCHAR(100) PRIMARY KEY,
            category_sections LONGTEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )");
    }

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'category_sections'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN category_sections LONGTEXT DEFAULT NULL");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_category_sections (seller_username, category_sections) VALUES (?, ?) ON DUPLICATE KEY UPDATE category_sections = VALUES(category_sections)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $category_sections);
        $stmt1->execute();
    }

    $stmt2 = $conn->prepare("UPDATE sellers SET category_sections = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $category_sections, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Category sections saved successfully",
        "seller_username" => $seller_username,
        "category_sections" => json_decode($category_sections, true) ?? []
    ]);
    exit();
} elseif ($action == 'get-seller-category-sections') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $category_sections = [];
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_category_sections'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT category_sections FROM seller_category_sections WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $raw = trim($row1['category_sections'] ?? '');
                if (!empty($raw)) {
                    $decoded = json_decode($raw, true);
                    if (is_array($decoded)) $category_sections = $decoded;
                }
            }
        }

        if (empty($category_sections)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'category_sections'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT category_sections FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $raw = trim($row2['category_sections'] ?? '');
                    if (!empty($raw)) {
                        $decoded = json_decode($raw, true);
                        if (is_array($decoded)) $category_sections = $decoded;
                    }
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "category_sections" => $category_sections
    ]);
    exit();
} elseif ($action == 'save-seller-home-layout') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $layout_order = '';
    if (isset($input['layout_order'])) {
        $layout_order = is_array($input['layout_order']) ? json_encode($input['layout_order']) : trim($input['layout_order']);
    } elseif (isset($input['layout'])) {
        $layout_order = is_array($input['layout']) ? json_encode($input['layout']) : trim($input['layout']);
    }

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_home_layouts'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_home_layouts (
            seller_username VARCHAR(100) PRIMARY KEY,
            layout_order LONGTEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )");
    }

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'home_layout_order'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN home_layout_order LONGTEXT DEFAULT NULL");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_home_layouts (seller_username, layout_order) VALUES (?, ?) ON DUPLICATE KEY UPDATE layout_order = VALUES(layout_order)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $layout_order);
        $stmt1->execute();
    }

    $stmt2 = $conn->prepare("UPDATE sellers SET home_layout_order = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $layout_order, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Home layout saved successfully",
        "seller_username" => $seller_username,
        "layout_order" => json_decode($layout_order, true) ?? []
    ]);
    exit();
} elseif ($action == 'get-seller-home-layout') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $layout_order = [];
    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_home_layouts'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT layout_order FROM seller_home_layouts WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $raw = trim($row1['layout_order'] ?? '');
                if (!empty($raw)) {
                    $decoded = json_decode($raw, true);
                    if (is_array($decoded)) $layout_order = $decoded;
                }
            }
        }

        if (empty($layout_order)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'home_layout_order'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT home_layout_order FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $raw = trim($row2['home_layout_order'] ?? '');
                    if (!empty($raw)) {
                        $decoded = json_decode($raw, true);
                        if (is_array($decoded)) $layout_order = $decoded;
                    }
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "layout_order" => $layout_order
    ]);
    exit();
} elseif ($action == 'save-seller-search-bar-style' || $action == 'save-seller-search-hints') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $search_hints = '';
    if (isset($input['search_hints'])) {
        $search_hints = is_array($input['search_hints']) ? json_encode($input['search_hints']) : trim($input['search_hints']);
    } elseif (isset($input['hints'])) {
        $search_hints = is_array($input['hints']) ? json_encode($input['hints']) : trim($input['hints']);
    }

    $search_bg_color = isset($input['search_bg_color']) ? trim($input['search_bg_color']) : '#FFFFFF';
    $search_opacity = isset($input['search_opacity']) ? floatval($input['search_opacity']) : 1.0;
    $search_text_color = isset($input['search_text_color']) ? trim($input['search_text_color']) : '#0F172A';

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_search_bar_styles'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_search_bar_styles (
            seller_username VARCHAR(100) PRIMARY KEY,
            search_hints LONGTEXT,
            search_bg_color VARCHAR(50) DEFAULT '#FFFFFF',
            search_opacity FLOAT DEFAULT 1.0,
            search_text_color VARCHAR(50) DEFAULT '#0F172A',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    $colCheckHints = $conn->query("SHOW COLUMNS FROM sellers LIKE 'search_hints'");
    if (!$colCheckHints || $colCheckHints->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN search_hints LONGTEXT DEFAULT NULL");
    }

    $colCheckStyle = $conn->query("SHOW COLUMNS FROM sellers LIKE 'search_bar_style'");
    if (!$colCheckStyle || $colCheckStyle->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN search_bar_style LONGTEXT DEFAULT NULL");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_search_bar_styles (seller_username, search_hints, search_bg_color, search_opacity, search_text_color) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE search_hints = VALUES(search_hints), search_bg_color = VALUES(search_bg_color), search_opacity = VALUES(search_opacity), search_text_color = VALUES(search_text_color)");
    if ($stmt1) {
        $stmt1->bind_param("sssds", $seller_username, $search_hints, $search_bg_color, $search_opacity, $search_text_color);
        $stmt1->execute();
    }

    $stylePayload = json_encode([
        'search_bg_color' => $search_bg_color,
        'search_opacity' => $search_opacity,
        'search_text_color' => $search_text_color
    ]);
    $stmt2 = $conn->prepare("UPDATE sellers SET search_hints = ?, search_bar_style = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("ssss", $search_hints, $stylePayload, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Search bar style & watermarks saved successfully in database",
        "seller_username" => $seller_username,
        "search_hints" => json_decode($search_hints, true) ?: [],
        "search_bg_color" => $search_bg_color,
        "search_opacity" => $search_opacity,
        "search_text_color" => $search_text_color
    ]);
    exit();
} elseif ($action == 'get-seller-search-bar-style' || $action == 'get-seller-search-hints') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $search_hints = [];
    $search_bg_color = '#FFFFFF';
    $search_opacity = 1.0;
    $search_text_color = '#0F172A';

    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);

        $chk1 = $conn->query("SHOW TABLES LIKE 'seller_search_bar_styles'");
        if ($chk1 && $chk1->num_rows > 0) {
            $res1 = $conn->query("SELECT * FROM seller_search_bar_styles WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res1 && $row1 = $res1->fetch_assoc()) {
                $rawHints = trim($row1['search_hints'] ?? '');
                if (!empty($rawHints)) {
                    $decoded = json_decode($rawHints, true);
                    if (is_array($decoded)) $search_hints = $decoded;
                }
                if (!empty($row1['search_bg_color'])) $search_bg_color = $row1['search_bg_color'];
                if (isset($row1['search_opacity'])) $search_opacity = floatval($row1['search_opacity']);
                if (!empty($row1['search_text_color'])) $search_text_color = $row1['search_text_color'];
            }
        }

        if (empty($search_hints)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'search_hints'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT search_hints, search_bar_style FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $rawHints = trim($row2['search_hints'] ?? '');
                    if (!empty($rawHints)) {
                        $decoded = json_decode($rawHints, true);
                        if (is_array($decoded)) $search_hints = $decoded;
                    }
                    $rawStyle = trim($row2['search_bar_style'] ?? '');
                    if (!empty($rawStyle)) {
                        $styleDec = json_decode($rawStyle, true);
                        if (is_array($styleDec)) {
                            if (!empty($styleDec['search_bg_color'])) $search_bg_color = $styleDec['search_bg_color'];
                            if (isset($styleDec['search_opacity'])) $search_opacity = floatval($styleDec['search_opacity']);
                            if (!empty($styleDec['search_text_color'])) $search_text_color = $styleDec['search_text_color'];
                        }
                    }
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "search_hints" => $search_hints,
        "search_bg_color" => $search_bg_color,
        "search_opacity" => $search_opacity,
        "search_text_color" => $search_text_color
    ]);
    exit();
} elseif ($action == 'save-seller-action-buttons') {
    $seller_username = isset($input['seller_username']) ? trim($input['seller_username']) : (isset($_POST['seller_username']) ? trim($_POST['seller_username']) : '');
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);

    $action_buttons = '';
    if (isset($input['action_buttons'])) {
        $action_buttons = is_array($input['action_buttons']) ? json_encode($input['action_buttons']) : trim($input['action_buttons']);
    } elseif (isset($input['buttons'])) {
        $action_buttons = is_array($input['buttons']) ? json_encode($input['buttons']) : trim($input['buttons']);
    }

    if (empty($seller_username)) {
        echo json_encode(["success" => false, "message" => "Seller username required"]);
        exit();
    }

    $chkTable = $conn->query("SHOW TABLES LIKE 'seller_action_buttons'");
    if (!$chkTable || $chkTable->num_rows == 0) {
        @$conn->query("CREATE TABLE IF NOT EXISTS seller_action_buttons (
            seller_username VARCHAR(100) PRIMARY KEY,
            action_buttons LONGTEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'action_buttons'");
    if (!$colCheck || $colCheck->num_rows == 0) {
        @$conn->query("ALTER TABLE sellers ADD COLUMN action_buttons LONGTEXT DEFAULT NULL");
    }

    $stmt1 = $conn->prepare("INSERT INTO seller_action_buttons (seller_username, action_buttons) VALUES (?, ?) ON DUPLICATE KEY UPDATE action_buttons = VALUES(action_buttons)");
    if ($stmt1) {
        $stmt1->bind_param("ss", $seller_username, $action_buttons);
        $stmt1->execute();
    }

    $stmt2 = $conn->prepare("UPDATE sellers SET action_buttons = ? WHERE username = ? OR LOWER(username) = LOWER(?)");
    if ($stmt2) {
        $stmt2->bind_param("sss", $action_buttons, $seller_username, $seller_username);
        $stmt2->execute();
    }

    echo json_encode([
        "success" => true,
        "message" => "Action buttons style saved successfully in database",
        "seller_username" => $seller_username,
        "action_buttons" => json_decode($action_buttons, true) ?: new stdClass()
    ]);
    exit();
} elseif ($action == 'get-seller-action-buttons') {
    $seller_username = isset($_GET['seller_username']) ? trim($_GET['seller_username']) : (isset($input['seller_username']) ? trim($input['seller_username']) : '');
    if (empty($seller_username) && isset($_GET['username'])) $seller_username = trim($_GET['username']);
    if (empty($seller_username) && isset($input['username'])) $seller_username = trim($input['username']);

    $action_buttons = new stdClass();

    if (!empty($seller_username)) {
        $escapedSeller = $conn->real_escape_string($seller_username);
        $chkTable = $conn->query("SHOW TABLES LIKE 'seller_action_buttons'");
        if ($chkTable && $chkTable->num_rows > 0) {
            $res = $conn->query("SELECT action_buttons FROM seller_action_buttons WHERE seller_username = '$escapedSeller' OR LOWER(seller_username) = LOWER('$escapedSeller') LIMIT 1");
            if ($res && $row = $res->fetch_assoc()) {
                $raw = trim($row['action_buttons'] ?? '');
                if (!empty($raw)) {
                    $decoded = json_decode($raw, true);
                    if (is_array($decoded)) $action_buttons = $decoded;
                }
            }
        }

        if (empty((array)$action_buttons)) {
            $colCheck = $conn->query("SHOW COLUMNS FROM sellers LIKE 'action_buttons'");
            if ($colCheck && $colCheck->num_rows > 0) {
                $res2 = $conn->query("SELECT action_buttons FROM sellers WHERE username = '$escapedSeller' OR LOWER(username) = LOWER('$escapedSeller') LIMIT 1");
                if ($res2 && $row2 = $res2->fetch_assoc()) {
                    $raw2 = trim($row2['action_buttons'] ?? '');
                    if (!empty($raw2)) {
                        $decoded2 = json_decode($raw2, true);
                        if (is_array($decoded2)) $action_buttons = $decoded2;
                    }
                }
            }
        }
    }

    echo json_encode([
        "success" => true,
        "seller_username" => $seller_username,
        "action_buttons" => $action_buttons
    ]);
    exit();
} else {
    echo json_encode(["success" => true, "message" => "Daily Mart API Active"]);
}

$conn->close();
?>
