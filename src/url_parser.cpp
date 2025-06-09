#include <Rcpp.h>
#include <string>
#include <vector>
#include <regex>

class URLParser {
private:
    // URL regex pattern to match scheme, host, port, path, query, fragment
    // This is a simplified version - production would use more robust parsing
    std::regex url_pattern;
    
public:
    URLParser() {
        // Simplified URL regex pattern
        url_pattern = std::regex(
            R"(^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?)"
        );
    }
    
    struct URLComponents {
        std::string scheme;
        std::string host;
        std::string port;
        std::string path;
        std::string query;
        std::string fragment;
        bool valid;
        std::string error_message;
        
        URLComponents() : valid(false) {}
    };
    
    URLComponents parse_url(const std::string& url) {
        URLComponents components;
        
        if (url.empty()) {
            components.error_message = "Empty URL";
            return components;
        }
        
        std::smatch matches;
        if (!std::regex_match(url, matches, url_pattern)) {
            components.error_message = "Invalid URL format";
            return components;
        }
        
        // Extract components
        if (matches[1].matched) {
            components.scheme = matches[1].str();
        }
        
        if (matches[2].matched) {
            std::string authority = matches[2].str();
            parse_authority(authority, components);
        }
        
        if (matches[3].matched) {
            components.path = matches[3].str();
        }
        
        if (matches[4].matched) {
            components.query = matches[4].str();
        }
        
        if (matches[5].matched) {
            components.fragment = matches[5].str();
        }
        
        components.valid = true;
        return components;
    }
    
private:
    void parse_authority(const std::string& authority, URLComponents& components) {
        // Simple authority parsing (host:port)
        size_t colon_pos = authority.find_last_of(':');
        
        if (colon_pos != std::string::npos) {
            // Check if this is actually a port (numeric)
            std::string potential_port = authority.substr(colon_pos + 1);
            bool is_port = true;
            
            for (char c : potential_port) {
                if (!std::isdigit(c)) {
                    is_port = false;
                    break;
                }
            }
            
            if (is_port && !potential_port.empty()) {
                components.host = authority.substr(0, colon_pos);
                components.port = potential_port;
            } else {
                components.host = authority;
            }
        } else {
            components.host = authority;
        }
    }
};

// URL manipulation functions that can be called from other C++ files
std::string extract_domain_from_url(const std::string& url) {
    URLParser parser;
    URLParser::URLComponents components = parser.parse_url(url);
    
    if (components.valid) {
        return components.host;
    }
    
    return "";
}

std::string replace_domain_in_url(const std::string& url, const std::string& new_domain) {
    URLParser parser;
    URLParser::URLComponents components = parser.parse_url(url);
    
    if (!components.valid) {
        return url; // Return original if parsing failed
    }
    
    // Reconstruct URL with new domain
    std::string result;
    
    if (!components.scheme.empty()) {
        result += components.scheme + "://";
    }
    
    result += new_domain;
    
    if (!components.port.empty()) {
        result += ":" + components.port;
    }
    
    if (!components.path.empty()) {
        result += components.path;
    }
    
    if (!components.query.empty()) {
        result += "?" + components.query;
    }
    
    if (!components.fragment.empty()) {
        result += "#" + components.fragment;
    }
    
    return result;
} 