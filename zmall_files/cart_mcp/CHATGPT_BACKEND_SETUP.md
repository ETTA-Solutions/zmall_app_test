# ChatGPT Integration - Backend Requirements

## Android Manifest Configuration

✅ **Completed for Android:**

- Internet permission
- Record audio (for voice input)
- External storage (for conversation history)
- Network security config for API calls

## Backend API Endpoints Needed

### 1. **Chat Message Endpoint**

```
POST /api/chatgpt/send-message
Headers:
  - Content-Type: application/json
  - Authorization: Bearer {user_token}

Request Body:
{
  "user_id": "string",
  "message": "string",
  "conversation_id": "string (optional)",
  "phone": "string"
}

Response:
{
  "success": boolean,
  "message": "string",
  "conversation_id": "string",
  "timestamp": "ISO 8601"
}
```

### 2. **Get Conversation History**

```
GET /api/chatgpt/conversations/{user_id}
Headers:
  - Authorization: Bearer {user_token}

Response:
{
  "success": boolean,
  "conversations": [
    {
      "conversation_id": "string",
      "created_at": "ISO 8601",
      "last_message": "string"
    }
  ]
}
```

### 3. **Get Chat Messages**

```
GET /api/chatgpt/messages/{conversation_id}
Headers:
  - Authorization: Bearer {user_token}

Response:
{
  "success": boolean,
  "messages": [
    {
      "id": "string",
      "sender": "user|bot",
      "message": "string",
      "timestamp": "ISO 8601"
    }
  ]
}
```

### 4. **Check ChatGPT Feature Status**

```
GET /api/chatgpt/status
Headers:
  - Authorization: Bearer {user_token}

Response:
{
  "success": boolean,
  "is_chatbot_active": boolean,
  "feature_enabled": boolean
}
```

## Database Schema (Backend)

### Table: `chatgpt_conversations`

```sql
CREATE TABLE chatgpt_conversations (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### Table: `chatgpt_messages`

```sql
CREATE TABLE chatgpt_messages (
  id UUID PRIMARY KEY,
  conversation_id UUID NOT NULL,
  sender VARCHAR(50) NOT NULL, -- 'user' or 'bot'
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (conversation_id) REFERENCES chatgpt_conversations(id)
);
```

### Update: `users` table

```sql
ALTER TABLE users ADD COLUMN is_chatbot_active BOOLEAN DEFAULT false;
```

## Environment Variables (Backend)

```
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_API_ENDPOINT=https://api.openai.com/v1
CHATGPT_SYSTEM_PROMPT="You are ZMall customer support assistant..."
```

## Key Configuration Values

| Field                  | Description             | Value              |
| ---------------------- | ----------------------- | ------------------ |
| `is_chatbot_active`    | Enable/disable per user | boolean            |
| `feature_enabled`      | Global feature flag     | boolean            |
| `service_name`         | Display name in app     | "ZMall AI Support" |
| `max_message_length`   | Character limit         | 1000               |
| `conversation_timeout` | Auto-close after (mins) | 30                 |

## Frontend Data Model (Already in place)

- File: `lib/utils/tab_screen.dart` - checks `is_chatbot_active`
- File: `lib/help/support_chat/support_chat_screen.dart` - chat UI
