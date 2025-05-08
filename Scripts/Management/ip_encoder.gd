extends RefCounted

# IP Encoder utility class for converting between IP addresses and Base36 encoded strings

# Convert an IP string (xxx.xxx.xxx.xxx) to a Base36 encoded string
func encode_ip(ip_address: String) -> String:
	# Convert IP to integer
	var parts = ip_address.split(".")
	if parts.size() != 4:
		print("[IP Encoder] Invalid IP format: " + ip_address)
		return "invalid"
		
	var ip_int = (int(parts[0]) << 24) | (int(parts[1]) << 16) | (int(parts[2]) << 8) | int(parts[3])
	
	# Convert to Base36
	return int_to_base36(ip_int)
	
# Convert an integer to a Base36 string
func int_to_base36(value: int) -> String:
	if value == 0:
		return "0"
		
	var chars = "0123456789abcdefghijklmnopqrstuvwxyz"
	var result = ""
	
	while value > 0:
		result = chars[value % 36] + result
		value /= 36
		
	return result

# Convert a Base36 encoded string back to an IP address string
func decode_ip(encoded: String) -> String:
	# Convert from Base36 to integer
	var ip_int = base36_to_int(encoded)
	
	# Convert integer to IP
	var a = (ip_int >> 24) & 0xFF
	var b = (ip_int >> 16) & 0xFF
	var c = (ip_int >> 8) & 0xFF
	var d = ip_int & 0xFF
	
	return "%d.%d.%d.%d" % [a, b, c, d]
	
# Convert a Base36 string to an integer
func base36_to_int(encoded: String) -> int:
	var chars = "0123456789abcdefghijklmnopqrstuvwxyz"
	var result = 0
	
	for c in encoded.to_lower():
		var value = chars.find(c)
		if value == -1:
			print("[IP Encoder] Invalid character in encoded string: " + c)
			return 0  # Invalid character
		result = result * 36 + value
		
	return result

# Validate if a string looks like a Base36 encoded IP
func is_valid_encoded_ip(encoded: String) -> bool:
	if encoded.length() < 1 or encoded.length() > 8:
		return false
		
	var chars = "0123456789abcdefghijklmnopqrstuvwxyz"
	for c in encoded.to_lower():
		if chars.find(c) == -1:
			return false
			
	return true

# Validate if a string looks like a standard IP address
func is_valid_ip_format(ip: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$")
	return regex.search(ip) != null 