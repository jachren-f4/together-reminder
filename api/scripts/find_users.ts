import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

const supabase = createClient(
  process.env.SUPABASE_URL || '',
  process.env.SUPABASE_SERVICE_ROLE_KEY || ''
);

async function findUsers() {
  // Get couples with user info
  const { data: couples, error } = await supabase
    .from('couples')
    .select('id, user1_id, user2_id')
    .limit(5);

  if (error) {
    console.error('Error:', error.message);
    return;
  }

  console.log('Couples:', JSON.stringify(couples, null, 2));

  // Get user metadata from auth
  const { data: users } = await supabase.auth.admin.listUsers();
  if (users && users.users) {
    console.log('\nUsers:');
    for (const user of users.users) {
      const name = user.user_metadata && user.user_metadata.full_name ? user.user_metadata.full_name : 'No name';
      console.log('- ' + name + ': ' + user.id);
    }
  }
}

findUsers();
